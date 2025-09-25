#!/bin/bash

# Usage: ./wp-create.sh domain single|multisite
DOMAIN=$1
TYPE=$2
WEB_ROOT="/var/www/$DOMAIN"
SSL_DIR="/etc/apache2/ssl"
APACHE_CONF_DIR="/etc/apache2/sites-available"

if [ -z "$DOMAIN" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 domain single|multisite"
    exit 1
fi

# Check if site already exists
if [ -d "$WEB_ROOT" ] || [ -f "$WEB_ROOT/wp-config.php" ] || [ -f "$APACHE_CONF_DIR/$DOMAIN.conf" ]; then
    echo "❌ WordPress site $DOMAIN already exists. Aborting."
    exit 1
fi

DB_NAME=$(echo $DOMAIN | tr . _)
DB_USER=$DB_NAME
DB_PASS=$DB_NAME

echo "🔍 Checking prerequisites..."

# Install package if missing
install_if_missing() {
    if ! command -v $1 &>/dev/null; then
        echo "📦 Installing $1..."
        sudo apt install $1 -y
    fi
}

# Core packages
for pkg in apache2 mysql-server php libapache2-mod-php php-mysql php-xml php-curl php-zip php-mbstring php-gd wget curl unzip; do
    install_if_missing $pkg
done

sudo systemctl enable apache2 mysql
sudo systemctl start apache2 mysql
sudo systemctl restart apache2

# WP-CLI
if ! command -v wp &>/dev/null; then
    echo "📦 Installing WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
fi

echo "✅ All prerequisites installed."

# Create DB
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Create web root
sudo mkdir -p $WEB_ROOT
sudo chown -R $USER:$USER $WEB_ROOT

# Download WordPress
if ls ~/.wp-cli/cache/core/wordpress-*.tar.gz 1> /dev/null 2>&1; then
    echo "📦 Using cached WordPress..."
    wp core download --path=$WEB_ROOT --skip-content
else
    echo "⬇️ Downloading latest WordPress..."
    wp core download --path=$WEB_ROOT
fi

# Create wp-config
wp config create --path=$WEB_ROOT --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --locale=en_US --skip-check

# Install WordPress
wp core install --path=$WEB_ROOT --url="http://$DOMAIN" --title="$DOMAIN" --admin_user=admin --admin_password=admin --admin_email=admin@$DOMAIN
if [ "$TYPE" = "multisite" ]; then
    wp core multisite-convert --path=$WEB_ROOT --title="$DOMAIN Multisite"
fi

# Ensure theme installed
if ! wp theme is-installed twentytwentyfive --path=$WEB_ROOT; then
    wp theme install twentytwentyfive --activate --path=$WEB_ROOT
else
    wp theme activate twentytwentyfive --path=$WEB_ROOT
fi

# Create .htaccess
cat > $WEB_ROOT/.htaccess <<EOL
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOL

# Adminer
ADMINER_DIR="$WEB_ROOT/adminer"
mkdir -p $ADMINER_DIR
if [ -f /usr/local/share/adminer/adminer.php ]; then
    cp /usr/local/share/adminer/adminer.php $ADMINER_DIR/adminer.php
else
    wget -q "https://www.adminer.org/latest.php" -O $ADMINER_DIR/adminer.php
    sudo mkdir -p /usr/local/share/adminer
    sudo cp $ADMINER_DIR/adminer.php /usr/local/share/adminer/adminer.php
fi
cat > $ADMINER_DIR/index.php <<EOPHP
<?php
define("ADMINER_AUTODETECT", true);
\$_GET["server"] = "localhost";
\$_GET["username"] = "$DB_USER";
\$_GET["password"] = "$DB_PASS";
\$_GET["db"] = "$DB_NAME";
include "adminer.php";
?>
EOPHP

# mkcert
if ! command -v mkcert &>/dev/null; then
    echo "📦 Installing mkcert..."
    sudo apt install libnss3-tools wget -y
    wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.2/mkcert-v1.4.2-linux-amd64
    chmod +x mkcert-v1.4.2-linux-amd64
    sudo mv mkcert-v1.4.2-linux-amd64 /usr/local/bin/mkcert
    mkcert -install
fi

# Generate HTTPS certificate if missing
if [ ! -f "$DOMAIN.pem" ]; then
    mkcert $DOMAIN
fi
sudo mkdir -p $SSL_DIR
sudo mv "$DOMAIN.pem" "$SSL_DIR/$DOMAIN.crt"
sudo mv "$DOMAIN-key.pem" "$SSL_DIR/$DOMAIN.key"

# Apache config
sudo bash -c "cat > $APACHE_CONF_DIR/$DOMAIN.conf <<EOL
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>
EOL"

sudo bash -c "cat > $APACHE_CONF_DIR/$DOMAIN-ssl.conf <<EOL
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $WEB_ROOT

    SSLEngine on
    SSLCertificateFile $SSL_DIR/$DOMAIN.crt
    SSLCertificateKeyFile $SSL_DIR/$DOMAIN.key

    <Directory $WEB_ROOT>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL"

sudo a2ensite $DOMAIN.conf
sudo a2ensite $DOMAIN-ssl.conf
sudo a2enmod rewrite ssl
sudo systemctl reload apache2

# Add to hosts
grep -qxF "127.0.0.1 $DOMAIN" /etc/hosts || echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts

echo "✅ WordPress site $DOMAIN created successfully!"
echo " - Access: http://$DOMAIN and https://$DOMAIN"
echo " - Adminer: http://$DOMAIN/adminer"
