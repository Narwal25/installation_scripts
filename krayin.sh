#!/bin/bash

set -x

# Define PHP version and server details as variables
PHP_VERSION="8.2"
SERVER_NAME="krayin.local"
KRAYIN_DB_NAME="krayin_db"
KRAYIN_DB_USER="krayin_user"
KRAYIN_DB_PASSWORD="krayin_password"
KRAYIN_REPO="https://github.com/krayin/laravel-crm.git"
KRAYIN_VERSION="master"

# Function to install Apache2
install_apache() {
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
}

# Function to install MySQL and create database and user
install_mysql() {
    sudo apt-get install mysql-server -y
    sudo mysql -e "
    CREATE DATABASE IF NOT EXISTS ${KRAYIN_DB_NAME};
    CREATE USER IF NOT EXISTS '${KRAYIN_DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${KRAYIN_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${KRAYIN_DB_NAME}.* TO '${KRAYIN_DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
    "
    # Log into MySQL and run the query to set global variable
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
}

# Function to install PHP and required extensions
install_php() {
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-opcache php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick libapache2-mod-php${PHP_VERSION}
    
    # Update PHP configurations
    sudo sed -i "s/^memory_limit = .*/memory_limit = 1024M/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini
}

# Function to enable Apache modules and restart Apache
enable_apache_modules() {
    sudo apt-get install libapache2-mpm-itk
    sudo a2enmod rewrite proxy_fcgi mpm_itk
    sudo systemctl restart apache2
}

# Function to install Composer
install_composer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php --version=2.5.8
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
}

# Function to clone Krayin repository
clone_krayin_repo() {
    if id krayin &>/dev/null; then
        echo "User 'krayin' already exists."
    else
        sudo useradd krayin
        echo "User 'krayin' created."
    fi
    mkdir -p /home/krayin
    chown -R krayin:krayin /home/krayin
    
    cd /home/krayin/ || exit
    git clone -b $KRAYIN_VERSION $KRAYIN_REPO
    cd laravel-crm || exit
    
    # Install Composer dependencies
    COMPOSER_ALLOW_SUPERUSER=1 composer install
}

# Function to configure the .env file for Krayin
configure_env() {
    cp .env.example .env
    
    # Modify the .env file settings
    sed -i "s/^APP_NAME=.*/APP_NAME=Krayin/" .env
    sed -i "s/^APP_DEBUG=.*/APP_DEBUG=false/" .env
    sed -i 's#^APP_URL=.*#APP_URL=http://localhost/#' .env
    sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
    sed -i "s/^DB_HOST=.*/DB_HOST=localhost/" .env
    sed -i "s/^DB_PORT=.*/DB_PORT=3306/" .env
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${KRAYIN_DB_NAME}/" .env
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${KRAYIN_DB_USER}/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${KRAYIN_DB_PASSWORD}/" .env
}

# Function to configure Apache for Krayin
configure_apache() {
    # Create Apache VirtualHost configuration for Krayin
    echo "
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /home/krayin/laravel-crm/public
        ServerName $SERVER_NAME
        AssignUserId krayin krayin
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory /home/krayin/laravel-crm/public>
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>
    " | sudo tee /etc/apache2/sites-available/krayin.local.conf
    
    # Disable the default site and enable the Krayin site
    sudo a2dissite 000-default.conf
    sudo a2ensite krayin.local.conf
    
    # Restart Apache to apply changes
    sudo systemctl restart apache2
}

# Function to install Krayin
install_krayin() {
    cd /home/krayin/laravel-crm/ || exit
    php artisan krayin-crm:install --no-interaction
}

Install_krayin_stack(){
    # Main execution
    install_apache
    install_mysql
    install_php
    enable_apache_modules
    install_composer
    clone_krayin_repo
    configure_env
    configure_apache
    install_krayin
    
    chown -R krayin:krayin /home/krayin
    echo "Installation complete!"
}

Install_krayin_stack
