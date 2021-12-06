#!/bin/bash

# Where THIS repo is on your server's filesystem
# This is an example install on a fresh ubuntu instance
DLUQSREPO="/home/ubuntu/DLUQuickstart"

# Clone the DLU Server repository if not done already
if ! [ -d "$DLUQSREPO/DarkflameServer" ]; then
	git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
fi

# Install any other dependencies (via apt for debian-ish distros)
echo -e "\n\nInstalling Dependencies..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar sqlite

### Compile DLU
# I had trouble compiling when using an AWS t3.micro instance (2vCPUs, 1GB RAM) due to ram limitations (probably) but could compile with a t3.small instance (2vCPUs, 2GB RAM)
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

# Install Account manager requirements
pip3 install -r "$DLUQSREPO/AccountManager/requirements.txt"

# Symbolically link files for account manager
ln -s "$DLUQSREPO/config/credentials.py" "$DLUQSREPO/AccountManager/credentials.py"
ln -s "$DLUQSREPO/config/resources.py" "$DLUQSREPO/AccountManager/resources.py"

### Get Utilities for unpacking client files
if ! [ -d "$DLUQSREPO/utils" ]; then
	cd "$DLUQSREPO"
	pip3 install git+https://github.com/lcdr/utils
	git clone https://github.com/lcdr/utils
fi

echo -e "Done!"
