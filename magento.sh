#!/bin/bash

set -xe

# Variables
IP=192.168.56.3
Magento_DB_NAME="magento_db"
Magento_DB_USER="magento_user"
Magento_DB_PASS="magento_pass"
PHP_VERSION="8.2"
MAGENTO_VERSION="2.4.7-p1"
OPENSEARCH_INITIAL_ADMIN_PASSWORD="OpenSearchPassword@"$IP

# Install necessary utilities
install_utilities() {
    sudo apt-get update
    sudo apt-get install curl wget zip unzip net-tools -y
}

# Update system and install Apache2
install_apache2() {
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
}

# Install MySQL server and set up database
install_mysql() {
    sudo apt-get install mysql-server -y
    sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
    
    sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $Magento_DB_NAME;"
    sudo mysql -u root -e "CREATE USER IF NOT EXISTS '$Magento_DB_USER'@'localhost' IDENTIFIED BY '$Magento_DB_PASS';"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $Magento_DB_NAME.* TO '$Magento_DB_USER'@'localhost';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"
}

# Install PHP and required extensions
install_php() {
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo apt-get install -y php${PHP_VERSION}-cli php${PHP_VERSION}-apcu php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-opcache php${PHP_VERSION}-soap php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick libapache2-mod-php${PHP_VERSION}
    
    # Update PHP configurations
    sudo sed -i "s/^memory_limit = .*/memory_limit = 1024M/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini
    sudo sed -i "s/^memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/fpm/php.ini
    sudo sed -i "s/^date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini
}

# Enable Apache modules
enable_apache_modules() {
    sudo a2enmod rewrite proxy_fcgi
    sudo systemctl restart apache2
}

# Install OpenSearch
install_opensearch() {
    rm -rf opensearch*.deb*
    wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.18.0/opensearch-2.18.0-linux-x64.deb
    sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD=$OPENSEARCH_INITIAL_ADMIN_PASSWORD dpkg -i opensearch-2.18.0-linux-x64.deb
    
    # Limit OpenSearch Memory and Disable security
    sed -i "s/.*-Xms.*/-Xms400m/" /etc/opensearch/jvm.options
    sed -i "s/.*-Xmx.*/-Xmx400m/" /etc/opensearch/jvm.options
    echo "plugins.security.disabled: true" >> /etc/opensearch/opensearch.yml

    sudo systemctl enable opensearch
    sudo systemctl start opensearch

}

# Install Elasticsearch
install_elasticsearch() {
    rm -rf elasticsearch*.deb*
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.16.0-amd64.deb
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.16.0-amd64.deb.sha512
    shasum -a 512 -c elasticsearch-8.16.0-amd64.deb.sha512
    sudo dpkg -i elasticsearch-8.16.0-amd64.deb
    
    # Limit Elasticsearch Memory and Disable security
    sed -i "s/.*-Xms.*/-Xms400m/" /etc/elasticsearch/jvm.options
    sed -i "s/.*-Xmx.*/-Xmx400m/" /etc/elasticsearch/jvm.options
    sed -i "s/.*xpack.security.enabled.*/xpack.security.enabled: false/" /etc/elasticsearch/elasticsearch.yml
    sed -i "s/.*xpack.security.enrollment.enabled.*/xpack.security.enrollment.enabled: false/" /etc/elasticsearch/elasticsearch.yml
    
    sudo systemctl enable elasticsearch
    sudo systemctl restart elasticsearch
}

# Install Composer
install_composer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php --version=2.5.8
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
}

# Install Magento
install_magento() {
    cd /var/www || exit
    sudo git clone -b $MAGENTO_VERSION https://github.com/magento/magento2.git magento
    
    # Set correct permissions
    sudo chown -R www-data:www-data /var/www/magento
    sudo chmod -R 755 /var/www/magento
}

# Install Magento dependencies using Composer
install_magento_dependencies() {
    cd /var/www/magento || exit
    sudo -u www-data composer install
}

# Set up Magento via CLI
setup_magento() {
    cd /var/www/magento || exit
    sudo -u www-data php bin/magento setup:install  -vvv --base-url=http://$IP/   --db-host=127.0.0.1   --db-name=$Magento_DB_NAME   --db-user=$Magento_DB_USER   --db-password=$Magento_DB_PASS   --admin-firstname=Admin   --admin-lastname=User   --admin-email=admin@example.com   --admin-user=admin   --admin-password=admin123   --language=en_US   --currency=USD   --timezone=America/Chicago   --use-rewrites=1
}

# Enable Magento Developer Mode
enable_developer_mode() {
    sudo -u www-data php bin/magento deploy:mode:set developer
}

# Create Apache VirtualHost configuration
configure_apache_virtualhost() {
    echo "
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/magento/pub
        ServerName magento2.local
        <Directory /var/www/magento>
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>
    " | sudo tee /etc/apache2/sites-available/magento.local.conf
    
    # Disable the default site and enable the Magento site
    sudo a2dissite 000-default.conf
    sudo a2ensite magento.local.conf
    
    # Restart Apache
    sudo systemctl restart apache2
}

# Main function to install everything
install_magento_stack() {
    install_utilities
    install_apache2
    install_mysql
    install_php
    enable_apache_modules
    install_opensearch
    install_composer
    install_magento
    install_magento_dependencies
    setup_magento
    enable_developer_mode
    configure_apache_virtualhost
    
    # Final permission fix
    sudo chown -R www-data:www-data /var/www/magento
    echo "Installation complete!"
}

# Run the installation
install_magento_stack
