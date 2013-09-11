# Copyright (c) 2013 Sylvain Boucher
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#!/usr/bin/env bash

#variables
SITE_NAME="sandbox"
DOCUMENT_ROOT="/vagrant"
MYSQL_ROOT_PASSWORD="toor"
DATABASE_NAME="sandbox"
DATABASE_USERNAME="sandbox"
DATABASE_PASSWORD="sandbox"

apt-get update

##Install services

#apache
apt-get install -y apache2

#php
apt-get install php5 -y libapache2-mod-php5

#mysql
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
apt-get install -y mysql-server
apt-get install -y php5-mysql

##Setup virtual hosts

a2enmod rewrite

cat >/etc/apache2/sites-available/$SITE_NAME.conf <<EOL
<VirtualHost *:80>
  DocumentRoot $DOCUMENT_ROOT
  <Directory $DOCUMENT_ROOT>
    AllowOverride All
    RewriteEngine On
  </Directory>
  EnableSendfile Off
  EnableMMAP Off
</VirtualHost>
EOL

a2dissite default
a2ensite $SITE_NAME.conf

sed -i s@APACHE_RUN_GROUP=www-data@APACHE_RUN_GROUP=vagrant@g /etc/apache2/envvars
sed -i s@APACHE_RUN_USER=www-data@APACHE_RUN_USER=vagrant@g /etc/apache2/envvars
chown vagrant:root /var/lock/apache2

service apache2 restart

##Create database

mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON $DATABASE_NAME.* TO '$DATABASE_USERNAME'@'localhost' identified by '$DATABASE_PASSWORD';"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"


debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_ROOT_PASSWORD"
apt-get install -y phpmyadmin
