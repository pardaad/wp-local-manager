# wp-local-manager

`wp-local-manager` is a set of **bash scripts** to quickly create and delete **WordPress sites** on a local Linux environment.
It automatically installs all needed components: **Apache, MySQL, PHP, WP-CLI, SSL**, and **Adminer**.

> ⚠️ **Note:** This is only for **local development**. Do **not** use in production.

---

## Files

* `wp-create.sh` → Script to **create a new WordPress site**
* `wp-delete.sh` → Script to **delete an existing WordPress site**

---

## Features

### wp-create.sh

This script automates the process of setting up a WordPress site locally:

* Installs missing packages: Apache, MySQL, PHP, WP-CLI, wget, curl, unzip
* Creates MySQL database and user automatically (database name, user, and password are based on domain)
* Downloads WordPress (uses cached version if exists)
* Creates `wp-config.php`
* Installs WordPress (supports **single** or **multisite**)
* Installs and activates **Twenty Twenty-Five** theme
* Creates `.htaccess` for pretty permalinks
* Installs **Adminer** with auto-login for the site's database
* Generates local HTTPS certificate using `mkcert`
* Creates Apache configuration files and enables the site
* Adds domain to `/etc/hosts`

### wp-delete.sh

This script removes a WordPress site safely:

* Checks if the site exists before delete
* Disables Apache site and reloads Apache
* Deletes web root folder
* Deletes SSL certificates
* Removes Apache configuration files
* Removes domain from `/etc/hosts`
* Drops MySQL database and user
* Requests confirmation before deleting

---

## Requirements

* Linux (Ubuntu tested)
* Bash
* `sudo` privileges
* Internet connection for first run (to install packages and download WordPress/Adminer)

---

## Installation

1. Clone the repository:

```bash
git clone https://github.com/pardaad/wp-local-manager.git
cd wp-local-manager
```

2. Make the scripts executable:

```bash
chmod +x wp-create.sh wp-delete.sh
```

---

## Usage

### Create a WordPress site

```bash
./wp-create.sh example.local single
```

or for multisite:

```bash
./wp-create.sh example.local multisite
```

* Replace `example.local` with your site domain
* `single` → normal WordPress site
* `multisite` → WordPress multisite
* If site already exists, the script **aborts with an error**

### Delete a WordPress site

```bash
./wp-delete.sh example.local
```

* Replace `example.local` with your site domain
* The script **asks for confirmation** before deleting
* If the site does not exist, the script **aborts with an error**

---

## Access

* WordPress site: `http://example.local` and `https://example.local`
* Adminer: `http://example.local/adminer`

  * Database login is **auto-filled**

---

## How It Works

1. **Checks prerequisites** and installs missing packages.
2. **Creates database and user** based on domain.
3. **Downloads WordPress** and sets up `wp-config.php`.
4. **Installs WordPress** (single or multisite).
5. **Installs Adminer** for easy database access.
6. **Generates HTTPS certificate** for the domain using `mkcert`.
7. **Creates Apache configuration** and enables the site.
8. **Adds domain to /etc/hosts** for local access.

---

## Notes

* Scripts are intended for **local development only**
* Admin username/password: `admin` / `admin`
* Database name, user, password are automatically generated from domain
* SSL certificates are **local self-signed** using `mkcert`

---

## License

This project is **free to use and modify**.

---

## Example

```bash
# Create a single site
./wp-create.sh mysite.local single

# Create a multisite
./wp-create.sh mynetwork.local multisite

# Delete a site
./wp-delete.sh mysite.local
```

After creation:

* Visit your site: `http://mysite.local`
* Adminer: `http://mysite.local/adminer`
* Admin login: `admin` / `admin`


# Support

If you like this project and want to support me, you can buy me a coffee:

https://buymeacoffee.com/mehdisharif
