#!/bin/bash

# Usage: ./wp-delete.sh domain
DOMAIN=$1
WEB_ROOT="/var/www/$DOMAIN"
SSL_DIR="/etc/apache2/ssl"
APACHE_CONF_DIR="/etc/apache2/sites-available"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 domain"
    exit 1
fi

# Check if site exists
if [ ! -d "$WEB_ROOT" ] && [ ! -f "$WEB_ROOT/wp-config.php" ] && [ ! -f "$APACHE_CONF_DIR/$DOMAIN.conf" ]; then
    echo "❌ WordPress site $DOMAIN does not exist. Aborting."
    exit 1
fi

read -p "🗑️ Are you sure you want to delete $DOMAIN? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

DB_NAME=$(echo $DOMAIN | tr . _)
DB_USER=$DB_NAME

# Disable site in Apache
[ -f "$APACHE_CONF_DIR/$DOMAIN.conf" ] && sudo a2dissite "$DOMAIN.conf"
[ -f "$APACHE_CONF_DIR/$DOMAIN-ssl.conf" ] && sudo a2dissite "$DOMAIN-ssl.conf"
sudo systemctl reload apache2

# Remove web root
[ -d "$WEB_ROOT" ] && sudo rm -rf "$WEB_ROOT"

# Remove SSL certificates
sudo rm -f "$SSL_DIR/$DOMAIN.crt" "$SSL_DIR/$DOMAIN.key"

# Remove Apache config
sudo rm -f "$APACHE_CONF_DIR/$DOMAIN.conf" "$APACHE_CONF_DIR/$DOMAIN-ssl.conf"

# Remove from /etc/hosts
sudo sed -i "/127\.0\.0\.1 $DOMAIN/d" /etc/hosts

# Drop DB
sudo mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
sudo mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "✅ WordPress site $DOMAIN deleted successfully!"
