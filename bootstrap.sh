#!/usr/bin/env bash
# BEGIN ########################################################################
echo -e "-- ------------------ --\n"
echo -e "-- BEGIN BOOTSTRAPING --\n"
echo -e "-- ------------------ --\n"

# BOX ##########################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Updating hosts file for our environment"
echo -e "-----------------------------------------------------------------------"
sudo sed -i 's&127.0.1.1&192.168.99.40&g' /etc/hosts
sudo echo "192.168.99.41	magnoliapublic" >> /etc/hosts

echo -e "-----------------------------------------------------------------------"
echo -e "-- Updating packages list"
echo -e "-----------------------------------------------------------------------"
sudo apt-get update -y

# JAVA #######################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Updating Java packages list"
echo -e "-----------------------------------------------------------------------"
sudo add-apt-repository ppa:openjdk-r/ppa
sudo apt-get -y update

echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing Java"
echo -e "-----------------------------------------------------------------------"
sudo apt-get install -y openjdk-9-jre
sudo apt-get install -y openjdk-9-jdk

# NODE.JS ##########################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing Node.js"
echo -e "-----------------------------------------------------------------------"
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo apt-get install -y build-essential

# MYSQL ##########################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing MySQL"
echo -e "-----------------------------------------------------------------------"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -q -y install mysql-server

echo -e "-----------------------------------------------------------------------"
echo -e "-- Preparing MySQL root user permissions and an empty Magnolia schema"
echo -e "-----------------------------------------------------------------------"
sudo mysql -u root -e "drop user 'root'@'localhost';create user 'root'@'%' identified by '';create schema magnoliaauthor;create schema magnoliapublic;grant all privileges on *.* to 'root'@'%' with grant option;flush privileges"
sudo mysqladmin -u root password password

echo -e "-----------------------------------------------------------------------"
echo -e "-- Adjusting mysqld.cnf"
echo -e "-----------------------------------------------------------------------"
sudo sed -i 's&max_allowed_packet      = 16M&max_allowed_packet      = 32M\nwait_timeout      = 86400\ninteractive_timeout      = 86400&g' /etc/mysql/mysql.conf.d/mysqld.cnf

echo -e "-----------------------------------------------------------------------"
echo -e "-- Restarting MySQL"
echo -e "-----------------------------------------------------------------------"
sudo service mysql restart

echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing libmysql-java"
echo -e "-----------------------------------------------------------------------"
sudo apt-get install libmysql-java

# MAGNOLIA #######################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing Magnolia CLI"
echo -e "-----------------------------------------------------------------------"
sudo npm install -y @magnolia/cli -g

echo -e "-----------------------------------------------------------------------"
echo -e "-- Jumpstarting Magnolia"
echo -e "-----------------------------------------------------------------------"
cd /opt
sudo mkdir magnolia
sudo mgnl jumpstart -w magnolia-community-webapp

echo -e "-----------------------------------------------------------------------"
echo -e "-- Preparing Magnolia for MySQL Jackrabbit JCR persistence"
echo -e "-----------------------------------------------------------------------"
sudo rm -f /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/lib/derby-x.jar
sudo cp /usr/share/java/mysql.jar /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/lib/
sudo sed -i 's&jdbc:mysql://localhost:3306/magnolia&jdbc:mysql://localhost:3306/magnoliapublic&g' /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/config/repo-conf/jackrabbit-bundle-mysql-search.xml
sudo sed -i 's&DataSource name="magnolia"&DataSource name="magnoliapublic"&g' /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/config/repo-conf/jackrabbit-bundle-mysql-search.xml
sudo sed -i 's&"dataSourceName" value="magnolia"&"dataSourceName" value="magnoliapublic"&g' /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/config/repo-conf/jackrabbit-bundle-mysql-search.xml
sudo sed -i 's&magnolia.repositories.jackrabbit.config=WEB-INF/config/repo-conf/jackrabbit-bundle-h2-search.xml&magnolia.repositories.jackrabbit.config=WEB-INF/config/repo-conf/jackrabbit-bundle-mysql-search.xml&g' /opt/apache-tomcat/webapps/magnoliaPublic/WEB-INF/config/default/magnolia.properties

echo -e "-----------------------------------------------------------------------"
echo -e "-- Preparing Magnolia to be a public instance"
echo -e "-----------------------------------------------------------------------"
sudo sed -i 's/magnolia.bootstrap.authorInstance=true/magnolia.bootstrap.authorInstance=false/g' /opt/apache-tomcat/webapps/magnoliaAuthor/WEB-INF/config/default/magnolia.properties

echo -e "-----------------------------------------------------------------------"
echo -e "-- Preparing Magnolia for remote Java debugging"
echo -e "-----------------------------------------------------------------------"
cd /opt/apache-tomcat/bin/
sudo sed -i 's&# exec "$PRGDIR"/catalina.sh jpda start&exec "$PRGDIR"/catalina.sh jpda start&g' magnolia_control.sh

echo -e "-----------------------------------------------------------------------"
echo -e "-- Starting Magnolia"
echo -e "-----------------------------------------------------------------------"
sudo ./magnolia_control.sh start --ignore-open-files-limit

# NGINX #######################################################################
echo -e "-----------------------------------------------------------------------"
echo -e "-- Creating self-signed SSL cert"
echo -e "-----------------------------------------------------------------------"
sudo openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=magnoliaauthor" -keyout /etc/ssl/private/nginx-selfsigned.crt -out /etc/ssl/certs/nginx-selfsigned.cert
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

echo -e "-----------------------------------------------------------------------"
echo -e "-- Installing Nginx web server"
echo -e "-----------------------------------------------------------------------"
sudo apt-get install -y nginx

echo -e "-----------------------------------------------------------------------"
echo -e "-- Configuring Nginx for SSL"
echo -e "-----------------------------------------------------------------------"
sudo sed -i 's&# listen 443 ssl default_server;&listen 443 ssl default_server;&g' /etc/nginx/sites-available/default
sudo sed -i 's&# listen \[::\]:443 ssl default_server;&listen \[::\]:443 ssl default_server;&g' /etc/nginx/sites-available/default
sudo sed -i 's&# include snippets/snakeoil.conf;&include snippets/snakeoil.conf;&g' /etc/nginx/sites-available/default
sudo sed -i 's&ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;&ssl_certificate /etc/ssl/certs/nginx-selfsigned.cert;&g' /etc/nginx/snippets/snakeoil.conf
sudo sed -i 's&ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;&ssl_certificate_key /etc/ssl/private/nginx-selfsigned.crt;&g' /etc/nginx/snippets/snakeoil.conf

echo -e "-----------------------------------------------------------------------"
echo -e "-- Configuring reverse proxy"
echo -e "-----------------------------------------------------------------------"
sudo bash -c "cat << 'EOF' > /etc/nginx/sites-available/default
##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# http://wiki.nginx.org/Pitfalls
# http://wiki.nginx.org/QuickStart
# http://wiki.nginx.org/Configuration
#
# Generally, you will want to move this file somewhere, and start with a clean
# file but keep this around for reference. Or just disable in sites-enabled.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
upstream tomcat {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
        listen 80 default_server;
        listen [::]:80 default_server;

        # SSL configuration
        #
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        #
        # Note: You should disable gzip for SSL traffic.
        # See: https://bugs.debian.org/773332
        #
        # Read up on ssl_ciphers to ensure a secure configuration.
        # See: https://bugs.debian.org/765782
        #
        # Self signed certs generated by the ssl-cert package
        # Don't use them in a production server!
        #
        include snippets/snakeoil.conf;

        root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;

        server_name _;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                #try_files $uri $uri/ =404;
		include proxy_params;
		proxy_pass http://tomcat/;
        }

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #       include snippets/fastcgi-php.conf;
        #
        #       # With php7.0-cgi alone:
        #       fastcgi_pass 127.0.0.1:9000;
        #       # With php7.0-fpm:
        #       fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #       deny all;
        #}

}

# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#       listen 80;
#       listen [::]:80;
#
#       server_name example.com;
#
#       root /var/www/example.com;
#       index index.html;
#
#       location / {
#               #try_files $uri $uri/ =404;
#       }
#}
EOF
"

echo -e "-----------------------------------------------------------------------"
echo -e "-- Restarting Nginx"
echo -e "-----------------------------------------------------------------------"
sudo systemctl restart nginx

# END ##########################################################################
echo -e "-- ---------------- --"
echo -e "-- END BOOTSTRAPING --"
echo -e "-- ---------------- --"
