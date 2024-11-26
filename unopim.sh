#!/bin/bash

# Variables for the environment
PHP_VERSION="8.2"
Unopim_DB_NAME="unopim_db"
Unopim_DB_USER="unopim_user"
Unopim_DB_PASSWORD="unopim_password"
SERVER_NAME="unopim.local"
USER_NAME="unopim"
REPO_URL="https://github.com/unopim/unopim.git"

# Function to update system and install Apache2
install_apache() {
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
}

# Function to install MySQL and setup database and user
install_mysql() {
    sudo apt-get install mysql-server -y
    sudo mysql -e "
    CREATE DATABASE IF NOT EXISTS ${Unopim_DB_NAME};
    CREATE USER IF NOT EXISTS '${Unopim_DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${Unopim_DB_PASSWORD}';
    ALTER USER '${Unopim_DB_USER}'@'localhost' IDENTIFIED BY '${Unopim_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${Unopim_DB_NAME}.* TO '${Unopim_DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
    "
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
}

# Function to install PHP and required extensions
install_php() {
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-opcache php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick libapache2-mod-php${PHP_VERSION}
    
    # Update PHP configurations for CLI
    sudo sed -i 's/^memory_limit = .*/memory_limit = 1024M/' /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/${PHP_VERSION}/cli/php.ini

    # Update PHP configurations for FPM
    sudo sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/${PHP_VERSION}/fpm/php.ini
}

# Function to enable necessary Apache modules and restart Apache
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
    sudo mv composer.phar /usr/local/bin/composer
}

# Function to create user and clone the repository
clone_repository() {
    if id ${USER_NAME} &>/dev/null; then
        echo "User '${USER_NAME}' already exists."
    else
        sudo useradd ${USER_NAME}
        echo "User '${USER_NAME}' created."
    fi
    sudo mkdir -p /home/${USER_NAME}
    sudo chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}
    
    cd /home/${USER_NAME}/ || exit
    git clone ${REPO_URL}
    cd unopim || exit
}

# Function to install Composer dependencies
install_dependencies() {
    COMPOSER_ALLOW_SUPERUSER=1 composer install
}

# Function to configure the .env file
configure_env() {
    cp .env.example .env
    
    sed -i "s/^APP_NAME=.*/APP_NAME=Unopim/" .env
    sed -i "s/^APP_DEBUG=.*/APP_DEBUG=false/" .env
    sed -i "s#^APP_URL=.*#APP_URL=http://localhost/#" .env
    sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
    sed -i "s/^DB_HOST=.*/DB_HOST=localhost/" .env
    sed -i "s/^DB_PORT=.*/DB_PORT=3306/" .env
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${Unopim_DB_NAME}/" .env
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${Unopim_DB_USER}/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${Unopim_DB_PASSWORD}/" .env
}

# Function to create Apache VirtualHost for the project
configure_apache_vhost() {
    echo "
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /home/${USER_NAME}/unopim/public
        ServerName ${SERVER_NAME}
        AssignUserId unopim www-data
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory /home/${USER_NAME}/unopim/public>
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>
    " | sudo tee /etc/apache2/sites-available/${SERVER_NAME}.conf
    
    # Disable default site and enable UnoPim site
    sudo a2dissite 000-default.conf
    sudo a2ensite ${SERVER_NAME}.conf
    sudo systemctl restart apache2
}

# Function to install UnoPim
install_unopim() {
    cd /home/${USER_NAME}/unopim/ || exit
    php artisan unopim:install --no-interaction
}

# Main execution function
install_unopim_stack() {
    install_apache
    install_mysql
    install_php
    enable_apache_modules
    install_composer
    clone_repository
    install_dependencies
    configure_env
    configure_apache_vhost
    install_unopim
    
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/unopim/
    echo "Installation complete!"
}

# Execute the installation
install_unopim_stack
