#!/bin/bash

# Define variables
PHP_VERSION="8.2"
BAGISTO_VERSION="v2.2.2"
SERVER_NAME="bagisto.local"
Bagisto_DB_NAME="bagisto_db"
Bagisto_DB_USER="bagisto_user"
Bagisto_DB_PASSWORD="bagisto_password"
BAGISTO_DIR="/home/bagisto"
BAGISTO_REPO="https://github.com/bagisto/bagisto.git"

# Function to install Apache
install_apache() {
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
}

# Function to install MySQL and configure database
install_mysql() {
    sudo apt-get install mysql-server -y
    sudo mysql -e "
    CREATE DATABASE $Bagisto_DB_NAME;
    CREATE USER '$Bagisto_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$Bagisto_DB_PASSWORD';
    ALTER USER '${Bagisto_DB_USER}'@'localhost' IDENTIFIED BY '${Bagisto_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON $Bagisto_DB_NAME.* TO '$Bagisto_DB_USER'@'localhost';
    FLUSH PRIVILEGES;
    "
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
}

# Function to install PHP and required extensions
install_php() {
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo apt-get install -y php$PHP_VERSION-cli php$PHP_VERSION-apcu php$PHP_VERSION-bcmath php$PHP_VERSION-curl php$PHP_VERSION-opcache php$PHP_VERSION-fpm php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-mysql php$PHP_VERSION-xml php$PHP_VERSION-zip php$PHP_VERSION-mbstring php$PHP_VERSION-imagick libapache2-mod-php$PHP_VERSION

    # Update PHP configurations
    sudo sed -i 's/^memory_limit = .*/memory_limit = 1024M/' /etc/php/$PHP_VERSION/cli/php.ini
    sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/$PHP_VERSION/cli/php.ini
    sudo sed -i 's/^memory_limit = .*/memory_limit = 1024M/' /etc/php/$PHP_VERSION/apache2/php.ini
    sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/$PHP_VERSION/apache2/php.ini
    sudo sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php/$PHP_VERSION/fpm/php.ini
    sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/$PHP_VERSION/fpm/php.ini
}

# Function to install Composer
install_composer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php --version=2.5.8
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/local/bin/composer
}

# Function to create Bagisto user and setup directory
create_bagisto_user() {
    if id "bagisto" &>/dev/null; then
        echo "User 'bagisto' already exists."
    else
        sudo useradd bagisto
        echo "User 'bagisto' created."
    fi
    mkdir -p $BAGISTO_DIR
    sudo chown -R bagisto:bagisto $BAGISTO_DIR
}

# Function to clone the Bagisto repository
clone_bagisto_repo() {
    cd $BAGISTO_DIR || exit
    git clone -b $BAGISTO_VERSION $BAGISTO_REPO
}

# Function to install dependencies using Composer
install_bagisto_dependencies() {
    cd $BAGISTO_DIR/bagisto || exit
    COMPOSER_ALLOW_SUPERUSER=1 composer install
}

# Function to configure the .env file
configure_env() {
    cp .env.example .env

    sed -i "s/^APP_NAME=.*/APP_NAME=Bagisto/" .env
    sed -i "s/^APP_DEBUG=.*/APP_DEBUG=false/" .env
    sed -i "s#^APP_URL=.*#APP_URL=http://localhost/#" .env
    sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
    sed -i "s/^DB_HOST=.*/DB_HOST=localhost/" .env
    sed -i "s/^DB_PORT=.*/DB_PORT=3306/" .env
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$Bagisto_DB_NAME/" .env
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$Bagisto_DB_USER/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$Bagisto_DB_PASSWORD/" .env
}

# Function to create Apache VirtualHost for Bagisto
configure_apache() {
    echo "
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot $BAGISTO_DIR/bagisto/public
        ServerName $SERVER_NAME
        AssignUserId bagisto bagisto
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory $BAGISTO_DIR/bagisto/public>
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>
    " | sudo tee /etc/apache2/sites-available/$SERVER_NAME.conf

    # Enable necessary Apache modules and restart Apache
    sudo apt-get install libapache2-mpm-itk
    sudo a2enmod rewrite proxy_fcgi mpm_itk
    sudo a2dissite 000-default.conf
    sudo a2ensite $SERVER_NAME.conf
    sudo systemctl restart apache2
}

# Function to install Bagisto via Artisan command
install_bagisto() {
    cd $BAGISTO_DIR/bagisto || exit
    php artisan bagisto:install --no-interaction
}

Install_bagisto_stack(){
    # Main Installation Process
    install_apache
    install_mysql
    install_php
    install_composer
    create_bagisto_user
    clone_bagisto_repo
    install_bagisto_dependencies
    configure_env
    configure_apache
    install_bagisto

    chown -R bagisto:bagisto $BAGISTO_DIR/bagisto
    echo "Installation complete!"
}

Install_bagisto_stack
