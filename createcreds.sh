#!/bin/bash

# Where the darkflame repo is
DLUQSREPO="/home/ubuntu/DLUQuickstart"

## TODO: Use Whiptail to actually have the user set thse variables:
# https://www.redhat.com/sysadmin/use-whiptail
whiptail --msgbox --title "DATABASE CREDENTIAL BUILDER" "WARNING: This script simplifies the configuration of your DLU server, but is NOT a replacement for good secret/password management or a secure MySQL configuration." 25 80

MYSQLUSER="dluadmin"
MYSQLPASS="fortheloveofallthatisgoodandholychangethispasswordbeforeyourunthis"
MYSQLHOST="localhost"
MYSQLDB="DLU"

sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"

sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"

sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"

sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"

echo "CREATE USER '$MYSQLUSER'@'$MYSQLHOST' IDENTIFIED WITH mysql_native_password BY '$MYSQLPASS';" | sudo mysql -u root 
echo "GRANT ALL ON $MYSQLDB . * TO '$MYSQLUSER'@'$MYSQLHOST';" | sudo mysql -u root 
echo "FLUSH PRIVILEGES;" | sudo mysql -u root 

echo -e "Done!"