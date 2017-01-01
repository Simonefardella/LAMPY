#!/usr/bin/env bash
DBPASSWORD="<YOUR_PASSWORD>" echo "*_*_*_*_*_*_*_*_ Running LAMP Automated installer *_*_*_*_*_*_*_*_";
if [ "`lsb_release -is`" == "Ubuntu" ] || [ "`lsb_release -is`" == "Debian" ] || [ "`lsb_release -is`" == "Raspbian" ]
then
if [ "`whoami`" == "root" ]
then
    export DEBIAN_FRONTEND=noninteractive

    echo "*_*_*_*_* Updating System *_*_*_*_*";
    apt-get update -y
    apt-get update --fix-missing -y
    apt-get upgrade -y
    echo "*_*_*_*_* Done *_*_*_*_*";

    if [ "`lsb_release -is`" == "Raspbian" ] #Soft-Overclocking Raspberry to 1 Ghz
    then
        echo "arm_freq=1000" >> /boot/config.txt
        echo "gpu_mem=256" >> /boot/config.txt
    fi

    echo "*_*_*_*_* Installing Htop, SSH Server and configuring remote SSH Login*_*_*_*_*";
    apt-get install -y htop;
    apt-get install -y openssh-server;
    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    service ssh restart
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Installing Tree *_*_*_*_*";
    apt-get install -y tree;
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Installing MySql Server and PhpMyAdmin *_*_*_*_*";

    if [ "`lsb_release -is`" == "Debian" ] || [ "`lsb_release -is`" == "Raspbian" ] #Debian or raspbian non interactive installation
    then
        echo "*_*_*_*_* Debian/Raspbian Mysql & PHPMYADMIN silent install *_*_*_*_*";
        debconf-set-selections <<< "mysql-server mysql-server/root_password password "$DBPASSWORD
        debconf-set-selections <<< "mysql-server mysql-server/root_password_again password "$DBPASSWORD
        debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
        debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password "$DBPASSWORD
        debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password "$DBPASSWORD
        debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password "$DBPASSWORD
        debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

    else #Ubuntu non interactive installation
        echo "*_*_*_*_* Ubuntu Mysql & PHPMYADMIN silent install *_*_*_*_*";
        echo "mysql-server mysql-server/root_password password $DBPASSWORD" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password $DBPASSWORD" | debconf-set-selections
        echo "phpmyadmin phpmyadmin/dbconfig-install boolean true"| debconf-set-selections
        echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWORD" | debconf-set-selections
        echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWORD" | debconf-set-selections
        echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWORD" | debconf-set-selections
        echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    fi

    apt-get install -y mysql-server libmysqld-dev phpmyadmin;

    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Removing old Apache 2 installations and Installing/Enabling/Configuring Apache 2 MPM Worker, Python Pip, Python mod_wsgi, VirtualEnv *_*_*_*_*";

    apt-get install -y apache2-mpm-prefork;
    apt-get install -y python3-pip;
    apt-get install -y libapache2-mod-wsgi-py3;

    a2dismod mpm_event
    a2dismod mpm_worker
    a2enmod mpm_prefork
    a2enmod info
    a2enmod status
    a2enmod wsgi
    a2enmod deflate
    a2enmod expires
    a2enmod headers
    sed -i "s/<\/VirtualHost>/\n<Location \/serverstatus>\nSetHandler server-status\nAllow from all\n<\/Location>\n<Location \/serverinfo>\nSetHandler server-info\nAllow from all\n<\/Location>\n<\/VirtualHost>/g" /etc/apache2/sites-enabled/*.conf
    apachectl configtest
    pip3 install virtualenv
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Assigning owner to /var/www folder and creating info.php file into php folder *_*_*_*_*";
    mkdir /var/www/html/php/
    echo "<?php phpinfo(); ?>" > /var/www/html/php/info.php
    chown -R www-data:www-data /var/www/ #Assuming that the owner of www folder is www-data user
    apachectl configtest
    service apache restart;
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Running database privileges granting to root user *_*_*_*_*";
    mysql -uroot --password=$DBPASSWORD -e "grant all privileges on *.* to 'root'@'%' identified by '$DBPASSWORD' WITH GRANT OPTION;"
    mysql -uroot --password=$DBPASSWORD -e "flush privileges;"
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Commenting MySql Bind Address *_*_*_*_*";
    systemctl restart mysql
    sed -i "s/bind-address = 127.0.0.1/#bind-address = 127.0.0.1/g" /etc/mysql/my.cnf
    sed -i "s/ bind-address = 127.0.0.1/#bind-address = 127.0.0.1/g" /etc/mysql/my.cnf
    sed -i "s/bind-address = 127.0.0.1/#bind-address = 127.0.0.1/g" /etc/mysql/my.cnf
    systemctl restart mysql
    echo "*_*_*_*_* Done *_*_*_*_*";

    if ! [ "`lsb_release -is`" == "Raspbian" ]
    then
        echo "*_*_*_*_* Installing PageSpeed Apache module *_*_*_*_*";
        wget https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb
        dpkg -i mod-pagespeed-*.deb
        rm mod-pagespeed-*.deb
        a2enmod pagespeed
        systemctl restart apache2
        echo "*_*_*_*_* Done *_*_*_*_*";

        echo "*_*_*_*_* Configuring PagesSpeed Apache module *_*_*_*_*";
        PAGESPEEDCONF=/etc/apache2/mods-available/pagespeed.conf
        sed -i "s/ModPagespeed off/ModPagespeed on/g" $PAGESPEEDCONF
        sed -i "s/\tModPagespeed off/\tModPagespeed on/g" $PAGESPEEDCONF
        sed -i "s/# ModPagespeedRewriteLevel CoreFilters/ModPagespeedRewriteLevel CoreFilters/g" $PAGESPEEDCONF
        sed -i "s/\tModPagespeedRewriteLevel CoreFilters/\tModPagespeedRewriteLevel CoreFilters/g" $PAGESPEEDCONF
        sed -i "s/\t# ModPagespeedRewriteLevel CoreFilters/\tModPagespeedRewriteLevel CoreFilters/g" $PAGESPEEDCONF

        sed -i "s/# ModPagespeedRewriteLevel PassThrough/\tModPagespeedRewriteLevel CoreFilters/g" $PAGESPEEDCONF
        sed -i "s/ModPagespeedRewriteLevel PassThrough/ModPagespeedRewriteLevel CoreFilters/g" $PAGESPEEDCONF
        sed -i "s/\t# ModPagespeedEnableFilters collapse_whitespace,elide_attributes/\tModPagespeedEnableFilters collapse_whitespace,elide_attributes/g" $PAGESPEEDCONF

        sed -i "s/# ModPagespeedEnableFilters collapse_whitespace,elide_attributes/ModPagespeedEnableFilters collapse_whitespace,elide_attributes/g" $PAGESPEEDCONF
        chmod -R a+w /var/cache/mod_pagespeed
        echo "*_*_*_*_* Done *_*_*_*_*";
    else
        echo "*_*_*_*_* Skipping Pagespeed installation: not avaiable for ARM arch *_*_*_*_*";
    fi

    echo "*_*_*_*_* Installing Monitorix (Server Graphical Statistics Tool) *_*_*_*_*";
    if ! [ "`lsb_release -is`" == "Raspbian" ]
    then
        echo "deb http://apt.izzysoft.de/ubuntu generic universe" >> /etc/apt/sources.list
    else
        echo "deb [arch=all] http://apt.izzysoft.de/ubuntu generic universe" >> /etc/apt/sources.list #Specific for ARM
    fi
    wget http://apt.izzysoft.de/izzysoft.asc
    apt-key add izzysoft.asc
    apt-get update
    apt-get install -y monitorix
    rm izzysoft.asc

    echo "*_*_*_*_* Adding Monitorix user to MySql *_*_*_*_*";
    mysql -uroot --password=$DBPASSWORD -e "CREATE USER 'monitorixuser'@'localhost' IDENTIFIED BY 'M-o-nitoriX$';" #User without any grant permission
    mysql -uroot --password=$DBPASSWORD -e "flush privileges;"
    echo "*_*_*_*_* Done *_*_*_*_*";

    MONITORIXCONF=/etc/monitorix/monitorix.conf
    MONITORIXDEBCONF=/etc/monitorix/conf.d/00-debian.conf
    sed -i "s/\tmysql\t\t= n/\tmysql\t\t= y/g" $MONITORIXCONF
    sed -i "s/ mysql = n/ mysql = y/g" $MONITORIXCONF
    sed -i "s/\tpagespeed\t= n/\tpagespeed\t= y/g" $MONITORIXCONF
    sed -i "s/ pagespeed = n/ pagespeed = y/g" $MONITORIXCONF
    sed -i "s/\t\t\/var\/run\/mysqld\/mysqld.sock = 3306, user, secret/\t\t\/var\/run\/mysqld\/mysqld.sock = 3306, monitorixuser, M-o-nitoriX$/g" $MONITORIXDEBCONF
    sed -i "s/\/var\/run\/mysqld\/mysqld.sock = 3306, user, secret/\/var\/run\/mysqld\/mysqld.sock = 3306, monitorixuser, M-o-nitoriX$/g" $MONITORIXDEBCONF
    systemctl restart monitorix
    echo "*_*_*_*_* Login at: http://server_ip:8080/monitorix *_*_*_*_*";
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Installing WebMin *_*_*_*_*";
    echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list
    echo "deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib" >> /etc/apt/sources.list
    wget http://www.webmin.com/jcameron-key.asc
    apt-key add jcameron-key.asc
    apt-get update
    apt-get install -y webmin
    rm jcameron-key.asc
    echo "*_*_*_*_* Login at: https://server_ip:10000 with your root username and password *_*_*_*_*";
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Installing SmartMonTool *_*_*_*_*";
    apt-get install -y smartmontools
    echo "*_*_*_*_* Done *_*_*_*_*";
    echo "*_*_*_*_* Updating System *_*_*_*_*";


    apt-get update -y
    apt-get update --fix-missing -y
    apt-get upgrade -y
    echo "*_*_*_*_* Done *_*_*_*_*";

    echo "*_*_*_*_* Cleaning Apt Cache *_*_*_*_*";
    apt-get clean -y
    apt-get autoremove -y
    echo "*_*_*_*_* Done *_*_*_*_*";
    echo "---> F-I-N-I-S-H-E-D <---";
else
    echo "*_*_*_*_* Run the script as root! *_*_*_*_*";
fi
else
    echo "Unsupported Operating System";
fi