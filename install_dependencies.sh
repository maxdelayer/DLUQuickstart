#!/bin/bash

# Where THIS repo is on your server's filesystem
DLUQSREPO="/home/ubuntu/DLUQuickstart"

# Clone the DLU Server repository
if ! [ -d "$DLUQSREPO/DarkflameServer" ]; then
	git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
fi

# Install any other dependencies (via apt for debian-ish distros)
echo -e "\n\nInstalling Dependencies..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar

### Compile
echo -e "\n\nBuilding..."
cd "$DLUQSREPO/DarkflameServer"
./build.sh

### CREATE DATABASE
echo -e "\n\nCreating Database..."
echo "CREATE DATABASE DLU;" | sudo mysql -u root 

# Choose the correct sql file to use. Because mysql complains, I made a custom one
#DATABASEPATH="$DLUREPO/DarkflameServer/migrations/dlu/0_initial.sql"
DATABASEPATH="$DLUQSREPO/0_initial.mysql"

sudo mysql -u root DLU < $DATABASEPATH

### Create Account Manager
if ! [ -d "$DLUQSREPO/AccountManager" ]; then
	cd "$DLUQSREPO"
	git clone https://github.com/DarkflameUniverse/AccountManager
fi

# Install requirements
pip3 -r "$DLUQSREPO/AccountManager/requirements.txt"

# Symbolically link files for account manager
ln -s "$DLUQSREPO/config/credentials.py" "$DLUQSREPO/AccountManager/credentials.py"
ln -s "$DLUQSREPO/config/resources.py" "$DLUQSREPO/AccountManager/resources.py"

# Symbolically link files for server itself
# TODO: is this a good idea? uhhhhh maybe lets not
# Use Sed to change your config instead! (update_config.sh)
#ln -s "$DLUQSREPO/config/authconfig.ini"   "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
#ln -s "$DLUQSREPO/config/chatconfig.ini"   "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
#ln -s "$DLUQSREPO/config/worldconfig.ini"  "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
#ln -s "$DLUQSREPO/config/masterconfig.ini" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"

### Get Utilities for unpacking client files
if ! [ -d "$DLUQSREPO/utils" ]; then
	cd "$DLUQSREPO"
	git clone https://github.com/lcdr/utils
fi

echo -e "Done!"
