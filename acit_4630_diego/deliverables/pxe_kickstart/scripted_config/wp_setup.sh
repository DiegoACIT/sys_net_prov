#!/bin/bash

cat > /home/admin/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCu25cbwUSf2jqveyo/jOle1U2c4V0VXgKYMS9G/374TLxcslzPp2rvPSXYiQIibVSqBv/thvxs8iRm9uLNtd3dwD8Npb/RfXd/I0upoMdMSj/1cDQoY/Rype/JLlaBCdv9UIZeJaur/Ddr0ZdBS7ftMmrOow3A4Tv6cejC+D/wMHr2HVi7lb0zS8vewhhCQSjbx6t+2MxU8c7xfEy944abc6AIHIixJjVo0ETivC9+GPQopF7fWFfrUuErf+1CRerTX3MvsSWSVvdzfvjqnDkW7BAQUsYaWdh6ladXBkxua32UCiqXNwusmXzyeSCVNh8Zt+yi1yT3ZQvHZlW4YWehMQGKxCSLJkkPCcITCkX4l02cs2OMo6Fd5bwggdoXRv1BY9o2/3FXHdYry+oampOyORUYijo6hUs7BbcEUlKMp+LCdr+vOwAjlvKZ5NfgfOxUVAvwcO89fSteYSmd5i6+VNVjBpytXNshMLZA9XZN6fBuYYsL4rf6IWvbWbsrgRzcmas4lcR+UB4SkPTVPAqIiQ0sYENwT03g2wXDHjEdLEVjDnDi9ib8hnl/J1ZeAbVFjFKN8hvP6VCe1tBoWeHmxoDKRsF85dCYpVCaqTi0B4Mbs78Ew0w9bh7GYVSgRkJahXDu9qUOAyuuE0WQRgDvCtduIygFpHNdiX3FxrK7IQ== acit_admin

EOF


######  disable SELINUX #########

setenforce 0
sed -r -i 's/SELINUX=(enforcing|disabled)/SELINUX=permissive/' /etc/selinux/config


######### install packages #######

yum groupinstall "base" -y
yum install vim git epel-release tcpdump nmap-ncat curl -y
yum update -y

########## firewall configuration #########

fire="firewall-cmd --permanent"

$fire --add-port=22/tcp
$fire --add-port=80/tcp
$fire --add-port=443/tcp
firewall-cmd --reload

########## install nginx and test ########

yum install nginx -y
systemctl enable nginx
systemctl start nginx

########### install nad configure mariadb ########

yum groupinstall "MariaDB" "mariadb-client" -y
systemctl enable mariadb
systemctl start mariadb

yum -y install expect

#// Not required in actual script
MYSQL_ROOT_PASSWORD=P@ssw0rd

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password:\"
send \"P@ssw0rd\r\" 
expect \"Re-enter new password:\r\"
send \"P@ssw0rd\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"



############## install and configure php ##########

yum install php php-mysql php-fpm -y
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
vim -c ':%s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php-fpm.sock/g' -c :wq! /etc/php-fpm.d/www.conf
vim -c ':%s/;listen.owner = nobody/listen.owner = nobody/g' -c ':%s/;listen.group = nobody/listen.group = nobody' -c ':%s/user = apache/user = nginx/g' -c ':%s/group = apache/group = nginx/g' -c :wq! /etc/php-fpm.d/www.conf



############### configure nginx ################

cat > /etc/nginx/nginx.conf <<EOF 

# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;
	index index.php index.html index.htm;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
	location ~ \.php$ {
	    try_files \$uri =404;
	    fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
            fastcgi_index index.php;
	    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	    include fastcgi_params;
        }
    }
}

EOF







############## database configuration for wordpress #############



mysql -pP@ssw0rd -e 'CREATE DATABASE wordpress;'
mysql -pP@ssw0rd -e 'CREATE USER 'wordpress_user'@'localhost' IDENTIFIED BY "'P@ssw0rd'";'
mysql -pP@ssw0rd -e 'GRANT ALL PRIVILEGES ON wordpress.* TO wordpress_user@localhost;'
mysql -pP@ssw0rd -e 'flush privileges;'
mysql -pP@ssw0rd -e "SELECT user FROM mysql.user;"
mysql -pP@ssw0rd -e "show schemas;"





vim -c ':%s/database_name_here/wordpress/g' -c ':%s/username_here/wordpress_user/g' -c ':%s/password_here/P@ssw0rd/g' -c :wq! wordpress/wp-config.php



rsync -avP wordpress/ /usr/share/nginx/html/
mkdir /usr/share/nginx/html/wp-content/uploads
chown -R admin:nginx /usr/share/nginx/html/*
systemctl restart nginx
yum -y install kernel-devel kernel-headers dkms gcc gcc-c++ kexec-tools
