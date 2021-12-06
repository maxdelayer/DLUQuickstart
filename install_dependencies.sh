#!/bin/bash

# Where the darkflame repo is
DLUQUICKSTARTREPO="/home/ubuntu/DLUQuickstart"
DLUREPO="$DLUQUICKSTARTREPO/DarkflameServer"

# Clone the DLU Server repository
if ! [ -d "$DLUREPO" ]; then
	git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer
fi

# Install any other dependencies (via apt for debian-ish distros)
echo -e "\nInstalling Dependencies..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev

### Compile
echo -e "\nBuilding..."
cd "$DLUREPO"
./build.sh

### CREATE DATABASE
echo -e "\nCreating Database..."
echo "CREATE DATABASE DLU;" | sudo mysql -u root 
#DATABASEPATH="$DLUREPO/migrations/dlu/0_initial.sql"
DATABASEPATH="$DLUQUICKSTARTREPO/0_initial.mysql"
sudo mysql -u root DLU < $DATABASEPATH

echo -e "Done!"
