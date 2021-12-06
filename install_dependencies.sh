#!/bin/bash

# Where the darkflame repo is
DLUQUICKSTARTREPO="/home/ubuntu/DLUQuickstart"
DLUREPO="$DLUQSREPO/DarkflameServer"

# Clone the DLU Server repository
if ! [ -d "$DLUREPO" ]; then
	git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
fi

# Install any other dependencies (via apt for debian-ish distros)
echo -e "\nInstalling Dependencies..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar

### Compile
echo -e "\nBuilding..."
cd "$DLUREPO"
./build.sh

### CREATE DATABASE
echo -e "\nCreating Database..."
echo "CREATE DATABASE DLU;" | sudo mysql -u root 
#DATABASEPATH="$DLUREPO/migrations/dlu/0_initial.sql"
DATABASEPATH="$DLUQSREPO/0_initial.mysql"
sudo mysql -u root DLU < $DATABASEPATH

### Create Account Manager
cd "$DLUQSREPO"
if ! [ -d "$DLUQSREPO/AccountManager" ]; then
	git clone https://github.com/DarkflameUniverse/AccountManager
fi
# Install requirements
pip3 -r "$DLUQSREPO/AccountManager/requirements.txt"

# Symbolically link files for account manager
ln -s credentials.py "$DLUQSREPO/AccountManager/credentials.py"
ln -s resources.py "$DLUQSREPO/AccountManager/credentials.py"

echo -e "Done!"
