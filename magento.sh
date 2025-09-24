#!/bin/bash
set -xe

# Variables
IP=192.168.5.104
Magento_DB_NAME="magento_db"
Magento_DB_USER="magento_user"
Magento_DB_PASS="magento_pass"
PHP_VERSION="8.2"
MAGENTO_VERSION="2.4.7-p1"
OPENSEARCH_INITIAL_ADMIN_PASSWORD="OpenSearchPassword@"$IP

# Switches
USE_NGINX_FPM=False
USE_CUSTOM_USER=False

# Custom user/group/path (used only if USE_CUSTOM_USER=True)
CUSTOM_WEB_USER="pardeep.narwal"
CUSTOM_WEB_GROUP="wuser"
CUSTOM_MAGENTO_PATH="/home/users/pradeep.narwal/magento"

# Defaults (used if USE_CUSTOM_USER=False)
DEFAULT_WEB_USER="www-data"
DEFAULT_WEB_GROUP="www-data"
DEFAULT_MAGENTO_PATH="/var/www/magento"

if [ "$USE_CUSTOM_USER" = "True" ]; then
    WEB_USER="$CUSTOM_WEB_USER"
    WEB_GROUP="$CUSTOM_WEB_GROUP"
    MAGENTO_PATH="$CUSTOM_MAGENTO_PATH"
    APACHE_ASSIGNUSERID="AssignUserID ${WEB_USER} ${WEB_GROUP}"
else
    WEB_USER="$DEFAULT_WEB_USER"
    WEB_GROUP="$DEFAULT_WEB_GROUP"
    MAGENTO_PATH="$DEFAULT_MAGENTO_PATH"
    APACHE_ASSIGNUSERID=""
fi

# Utilities
install_utilities() {
    sudo apt-get update
    sudo apt-get install curl wget zip unzip net-tools git -y
}

# Apache2
install_apache2() {
    sudo apt-get install apache2 libapache2-mpm-itk  libapache2-mod-php${PHP_VERSION} -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
}

enable_apache_modules() {
    sudo a2enmod rewrite proxy_fcgi
    sudo systemctl restart apache2
}

configure_apache_virtualhost() {
    echo "
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot ${MAGENTO_PATH}/pub
        ServerName magento2.local
        <Directory ${MAGENTO_PATH}>
            AllowOverride All
            Require all granted
        </Directory>
        ${APACHE_ASSIGNUSERID}
    </VirtualHost>
    " | sudo tee /etc/apache2/sites-available/magento.local.conf
    
    sudo a2dissite 000-default.conf
    sudo a2ensite magento.local.conf
    sudo systemctl restart apache2
}

# Nginx + PHP-FPM
install_nginx_fpm() {
    sudo systemctl disable apache2 && sudo systemctl stop apache2 || echo "apache2 is not installed"
    sudo apt-get install nginx php${PHP_VERSION}-fpm -y
    sudo systemctl enable nginx php${PHP_VERSION}-fpm
    sudo systemctl start nginx php${PHP_VERSION}-fpm
}

setup_web_user() {
    sudo sed -i "s/^user .*/user ${WEB_USER} ${WEB_GROUP};/" /etc/nginx/nginx.conf
    sudo systemctl restart nginx
}

configure_php_fpm_pool() {
    local pool_file="/etc/php/${PHP_VERSION}/fpm/pool.d/magento.conf"
    echo "
[magento]
user = ${WEB_USER}
group = ${WEB_GROUP}
listen = /run/php/php${PHP_VERSION}-fpm-magento.sock
listen.owner = ${WEB_USER}
listen.group = ${WEB_GROUP}
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
php_admin_value[memory_limit] = 512M
" | sudo tee $pool_file

    sudo systemctl restart php${PHP_VERSION}-fpm
}

configure_nginx_magento() {
    echo "
upstream fastcgi_backend {
    server unix:/run/php/php${PHP_VERSION}-fpm-magento.sock;
}

server {
    listen 80;
    server_name magento2.local $IP;
    set \$MAGE_ROOT ${MAGENTO_PATH};
    set \$MAGE_MODE developer;

    include ${MAGENTO_PATH}/nginx.conf.sample;
}
" | sudo tee /etc/nginx/sites-available/magento.conf

    sudo ln -sf /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
}

# MySQL
install_mysql() {
    sudo apt-get install mysql-server -y
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
    sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $Magento_DB_NAME;"
    sudo mysql -u root -e "CREATE USER IF NOT EXISTS '$Magento_DB_USER'@'localhost' IDENTIFIED BY '$Magento_DB_PASS';"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $Magento_DB_NAME.* TO '$Magento_DB_USER'@'localhost';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"
}

# PHP
install_php() {
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl \
        php${PHP_VERSION}-opcache php${PHP_VERSION}-soap php${PHP_VERSION}-fpm php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip \
        php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick
    
    sudo sed -i "s/^memory_limit = .*/memory_limit = 1024M/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini
}

# OpenSearch
install_opensearch() {
    rm -rf opensearch*.deb*
    wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.18.0/opensearch-2.18.0-linux-x64.deb
    sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD=$OPENSEARCH_INITIAL_ADMIN_PASSWORD dpkg -i opensearch-2.18.0-linux-x64.deb
    
    sed -i "s/.*-Xms.*/-Xms400m/" /etc/opensearch/jvm.options
    sed -i "s/.*-Xmx.*/-Xmx400m/" /etc/opensearch/jvm.options
    echo "plugins.security.disabled: true" | sudo tee -a /etc/opensearch/opensearch.yml
    sudo systemctl enable opensearch
    sudo systemctl start opensearch
}

# Composer
install_composer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --version=2.5.8
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/local/bin/composer
}

# Magento
install_magento() {
    sudo mkdir -p $MAGENTO_PATH
    cd "$(dirname $MAGENTO_PATH)" || exit
    sudo git clone -b $MAGENTO_VERSION https://github.com/magento/magento2.git "$(basename $MAGENTO_PATH)"
    sudo chown -R ${WEB_USER}:${WEB_GROUP} $MAGENTO_PATH
    sudo chmod -R 755 $MAGENTO_PATH
}

install_magento_dependencies() {
    cd $MAGENTO_PATH || exit
    sudo -u ${WEB_USER} composer install
}

setup_magento() {
    cd $MAGENTO_PATH || exit
    sudo -u ${WEB_USER} php bin/magento setup:install -vvv \
      --base-url=http://$IP/ \
      --db-host=127.0.0.1 \
      --db-name=$Magento_DB_NAME \
      --db-user=$Magento_DB_USER \
      --db-password=$Magento_DB_PASS \
      --admin-firstname=Admin \
      --admin-lastname=User \
      --admin-email=admin@example.com \
      --admin-user=admin \
      --admin-password=admin123 \
      --language=en_US \
      --currency=USD \
      --timezone=America/Chicago \
      --use-rewrites=1
}

enable_developer_mode() {
    sudo -u ${WEB_USER} php ${MAGENTO_PATH}/bin/magento deploy:mode:set developer
}

# Main
install_magento_stack() {
    install_utilities
    install_mysql
    install_php
    install_opensearch
    install_composer
    install_magento
    install_magento_dependencies

    if [ "$USE_NGINX_FPM" = "True" ]; then
        install_nginx_fpm
        setup_web_user
        configure_php_fpm_pool
        configure_nginx_magento
    else
        install_apache2
        enable_apache_modules
        configure_apache_virtualhost
    fi

    setup_magento
    enable_developer_mode

    sudo chown -R ${WEB_USER}:${WEB_GROUP} $MAGENTO_PATH
    echo "Installation complete!"
}

install_magento_stack
