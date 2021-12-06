#!/bin/bash

# Clone the DLU Server repository
git clone --recursive https://github.com/DarkflameUniverse/DarkflameServer

# Where the darkflame repo is
DLUREPO="/home/ubuntu/DLUQuickstart/DarkFlameServer"

# Install any other dependencies (via apt for debian-ish distros)
sudo apt-get update
sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev

### Compile
cd "$DLUREPO"
./build.sh

### CREATE DATABASE
echo "CREATE DATABASE DLU;" | sudo mysql -u root 

DATABASEPATH="$DLUREPO/migrations/dlu/0_initial.sql"

sudo mysql -u root DLU < $DATABASEPATH