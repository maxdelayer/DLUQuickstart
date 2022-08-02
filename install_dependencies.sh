#!/bin/bash

# Where THIS repo is on your server's filesystem
# This is an example install on a fresh ubuntu instance
DLUQSREPO="/home/ubuntu/DLUQuickstart"

# This grabs all the other repositories used (DarkFlameServer, NexusDashboard, and lcdr utils)
git pull
git submodule update --init --recursive

# Install any other dependencies (via apt for debian-ish distros)
echo -e "\n\nInstalling Dependencies..."
sudo apt-get update
sudo apt-get install -y git python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar unzip sqlite libmagickwand-dev libssl-dev

### Install Nexus Dashboard dependencies
pip3 install gunicorn
pip3 install -r "$DLUQSREPO/NexusDashboard/requirements.txt"
flask db upgrade

### CREATE DATABASE
echo -e "\n\nCreating database..."
echo "CREATE DATABASE DLU;" | sudo mysql -u root 

# Migrations are now handled by the MasterServer in build.sh

### Compile DLU
echo -e "\n\nRunning build script..."
cd "$DLUQSREPO/DarkflameServer"
./build.sh 2

echo -e "\n\nDLU Dependencies installed and client built. Now ensure your client is hooked"
