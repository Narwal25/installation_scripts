#!/bin/bash

set -x

IP=192.168.53.3
# Update system and install Apache2
sudo apt-get update
sudo apt-get install apache2 -y

# Enable and start Apache2
sudo systemctl enable apache2
sudo systemctl start apache2

# Install MySQL server
sudo apt-get install mysql-server -y

# Log into MySQL and run the query to set global variable
sudo mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Create MySQL Database
DB_NAME="magento_db"
DB_USER="magento_user"
DB_PASS="magento_pass"

sudo mysql -u root -e "CREATE DATABASE $DB_NAME;"
sudo mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# Install PHP and required extensions
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update
sudo apt-get install -y php8.2-cli php8.2-apcu php8.2-bcmath php8.2-curl php8.2-opcache php8.2-soap php8.2-fpm php8.2-gd php8.2-intl php8.2-mysql php8.2-xml php8.2-zip php8.2-mbstring php8.2-imagick libapache2-mod-php8.2

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

# Install elasticsearch
rm -rf elasticsearch-8.16.0-amd64.deb*
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.16.0-amd64.deb
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.16.0-amd64.deb.sha512
shasum -a 512 -c elasticsearch-8.16.0-amd64.deb.sha512 
sudo dpkg -i elasticsearch-8.16.0-amd64.deb

# Limit Elastic Search Memory and Disable security
sed -i "s/.*-Xms.*/-Xms400m/" /etc/elasticsearch/jvm.options
sed -i "s/.*-Xmx.*/-Xmx400m/" /etc/elasticsearch/jvm.options
sed -i "s/.*xpack.security.enabled.*/xpack.security.enabled: false/" /etc/elasticsearch/elasticsearch.yml
sed -i "s/.*xpack.security.enrollment.enabled.*/xpack.security.enrollment.enabled: false/" /etc/elasticsearch/elasticsearch.yml

sudo systemctl enable elasticsearch
sudo systemctl restart elasticsearch

# Install Composer
php -r "copy('https://getcomposer.org/installer ', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --version=2.5.8
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer

# Install Magento (replace with your Magento version)
MAGENTO_VERSION="2.4.7-p1"  # Modify to desired Magento version
cd /var/www
sudo git clone -b $MAGENTO_VERSION https://github.com/magento/magento2.git magento

# Set correct permissions
sudo chown -R www-data:www-data /var/www/magento
sudo chmod -R 755 /var/www/magento

# Install Magento dependencies using Composer
cd /var/www/magento
sudo -u www-data composer install

# Set up Magento via CLI
cd /var/www/magento
sudo -u www-data php bin/magento setup:install   --base-url=http://$IP/   --db-host=127.0.0.1   --db-name=$DB_NAME   --db-user=$DB_USER   --db-password=$DB_PASS   --admin-firstname=Admin   --admin-lastname=User   --admin-email=admin@example.com   --admin-user=admin   --admin-password=admin123   --language=en_US   --currency=USD   --timezone=America/Chicago   --use-rewrites=1   --elasticsearch-host=127.0.0.1:9200   --search-engine=elasticsearch7

# Set proper file permissions again
sudo chown -R www-data:www-data /var/www/magento
sudo chmod -R 755 /var/www/magento

# Enable Magento Developer Mode
sudo -u www-data php bin/magento deploy:mode:set developer

# Create Apache VirtualHost configuration
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

# Set ownership of the Magento directory
sudo chown -R www-data:www-data /var/www/magento

echo "Installation complete!"

