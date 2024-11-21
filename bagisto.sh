#!/bin/bash

# Update system and install Apache2
sudo apt-get update
sudo apt-get install apache2 -y

# Enable and start Apache2
sudo systemctl enable apache2
sudo systemctl start apache2

# Install MySQL server
sudo apt-get install mysql-server -y

# Log into MySQL and run queries to setup database and user
sudo mysql -e "
CREATE DATABASE bagisto_db;
CREATE USER 'bagisto_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'bagisto_password';
GRANT ALL PRIVILEGES ON bagisto_db.* TO 'bagisto_user'@'localhost';
FLUSH PRIVILEGES;
"
# Log into MySQL and run the query to set global variable
sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Install PHP and required extensions
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update
sudo apt-get install -y php8.2-cli php8.2-apcu php8.2-bcmath php8.2-curl php8.2-opcache php8.2-fpm php8.2-gd php8.2-intl php8.2-mysql php8.2-xml php8.2-zip php8.2-mbstring php8.2-imagick libapache2-mod-php8.2

# Update CLI PHP configuration
sudo sed -i 's/^memory_limit = .*/memory_limit = 1024M/' /etc/php/8.2/cli/php.ini
sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/8.2/cli/php.ini

# Update FPM PHP configuration
sudo sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^date.timezone = .*/date.timezone = UTC/' /etc/php/8.2/fpm/php.ini

# Enable necessary Apache modules and restart Apache
sudo a2enmod rewrite proxy_fcgi
sudo systemctl restart apache2

# Install other utilities
sudo apt-get install curl wget zip unzip net-tools -y

# Install Composer
php -r "copy('https://getcomposer.org/installer ', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --version=2.5.8
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer

# Add a new user 'bagisto'
sudo useradd bagisto
mkdir -p /home/bagisto
chown -R bagisto:bagisto /home/bagisto

# Clone the bagisto repository
cd /home/bagisto/
git clone -b master https://github.com/bagisto/bagisto.git
cd bagisto

# Install Composer dependencies
COMPOSER_ALLOW_SUPERUSER=1
composer install

# Copy the example .env file
cp .env.example .env

# Change the .env file settings using sed
sed -i 's/^APP_NAME=.*/APP_NAME=Bagisto/' .env
sed -i 's/^APP_DEBUG=.*/APP_DEBUG=false/' .env
sed -i 's#^APP_URL=.*#APP_URL=http://localhost/# ' .env
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env
sed -i 's/^DB_HOST=.*/DB_HOST=localhost/' .env
sed -i 's/^DB_PORT=.*/DB_PORT=3306/' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=bagisto_db/' .env
sed -i 's/^DB_USERNAME=.*/DB_USERNAME=bagisto_user/' .env
sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=bagisto_password/' .env

# Create Apache VirtualHost configuration
echo "
<VirtualHost *:80>
ServerAdmin webmaster@localhost
DocumentRoot /home/bagisto/bagisto/public
ServerName bagisto.local
<Directory /home/bagisto/bagisto/public>
AllowOverride All
Require all granted
</Directory>
</VirtualHost>
" | sudo tee /etc/apache2/sites-available/bagisto.local.conf

# Change Apache user to 'bagisto'
sudo sed -i 's/^.*export APACHE_RUN_USER=.*$/export APACHE_RUN_USER=bagisto/' /etc/apache2/envvars
sudo sed -i 's/^.*export APACHE_RUN_GROUP=.*$/export APACHE_RUN_GROUP=bagisto/' /etc/apache2/envvars

# Disable the default site and enable the Bagisto site
sudo a2dissite 000-default.conf
sudo a2ensite bagisto.local.conf

# Restart Apache
sudo systemctl restart apache2

# Set ownership of the Bagisto directory
sudo chown -R bagisto:bagisto /home/bagisto

# Install Bagisto
cd /home/bagisto/bagisto/
php artisan bagisto:install --no-interaction

echo "Installation complete!"
