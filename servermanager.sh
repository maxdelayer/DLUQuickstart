#!/bin/bash

# Where THIS repo is on your server's filesystem. Automatically detected based on where this script is
DLUQSREPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLIENTROOT="$DLUQSREPO/client"

# Global variables for database login info
# user and database are sane defaults I've decided upon, and the host and password are asked for on runtime, when needed
DBUSER="dluadmin"
DBPASS=""
DBHOST="localhost"
DBNAME="DLU"

# Global variable for tracking the decision to 
HOSTCHOOSE="y"

# Global variable for tracking if the datbase globals have been updated
DBENTERED=false

### TWEAKED DEFAULT SETTINGS ###
MAXBANDWIDTH="0"
MAXMTU="768"

### INSTALLATION FUNCTIONS ###

# Get user info on the database connection
function dbconnect(){
	# If we've already asked for this information and set the global variables, don't ask again
	if [[ "$DBENTERED" == false ]]; then
		read -s -p "Enter the password for database user: " DBPASS
		echo -e "\n"
		read -p "Are you connecting to a remote database? [y/n]: " HOSTCHOOSE
		if [[ $HOSTCHOOSE == "y" || $HOSTCHOOSE == "Y" ]]; then
			read -p "Enter the hostname for database: " DBHOST
		else
			DBHOST="localhost"
		fi
		DBENTERED=true
	fi
}

# This grabs all the other repositories used (DarkFlameServer & NexusDashboard)
function updateSubmodules(){
	git pull
	git submodule update --init --recursive
	git submodule update --remote --merge
}

# Build the server and flag binaries properly
function buildDLU(){
	cd "$DLUQSREPO/DarkflameServer"
	./build.sh
	
	# Makes it so authserver can use port 1001 without sudo
	sudo setcap 'cap_net_bind_service=+ep' "$DLUQSREPO/DarkflameServer/build/AuthServer"
}

function installDependencies(){
	# Update git repositories
	updateSubmodules
	
	# Install any other dependencies (via apt for debian-ish distros)
	sudo apt-get update
	sudo apt-get install -y python3 python3-pip gcc cmake zlib1g zlib1g-dev unrar unzip sqlite libmagickwand-dev libssl-dev python3-flask python3-gunicorn gunicorn mariadb-client

	# Potentially useful for secrets management in AWS down the line
	#apt-get install -y awscli

	### Install Nexus Dashboard dependencies
	pip3 install -r "$DLUQSREPO/NexusDashboard/requirements.txt"

	### Compile DLU
	buildDLU
}

function hookClient() {
	# Grab a lego universe client. If you have one, you can manually move it into place, if not, hey, check out this one I found:
	CLIENTLINK="https://archive.org/download/lego-universe-unpacked/LEGO Universe (unpacked).rar"
	CLIENTNAME="LEGO Universe (unpacked).rar"
	# NexusDashboard needs an unpacked client to work properly, so we use one of those
	
	# Link client location
	# If you're downloading a different client link, you'll probably need to change this. The 'res' folder should be in this directory
	CLIENTPATH="$CLIENTROOT"
	
	# Only downloads if the file isn't already present
	if [[ ! -f "$CLIENTROOT/$CLIENTNAME" ]]; then
		wget "$CLIENTLINK" -P "$CLIENTROOT/"
	fi
	
	# Only extract if the folders we're expecting from extraction isn't there
	if [[ ! -d "$CLIENTPATH/res/" ]]; then
		unrar x "$CLIENTROOT/$CLIENTNAME" "$CLIENTROOT/"
		
		# If we have just done an extraction, then the sqlite will be 'fresh' and we need to run migrations again the next time the masterserver starts
		# Remove references to old sqlite migrations that may not be valid anymore
		dbconnect
		mysql -u $DBUSER -D $DBNAME -h $DBHOST -p$DBPASS -e "DELETE FROM migration_history WHERE name LIKE 'cdserver/%'"
	fi

	sed -i "s|^client_location=.*$|client_location=$CLIENTPATH/|g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"

	# Change config so that it doesn't launch authserver as root
	sed -i "s|^use_sudo_auth=.*$|use_sudo_auth=0|g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
	
	### Link Nexus Dashboard config
	ln -sf "$DLUQSREPO/config/nexusdashboard.py" "$DLUQSREPO/NexusDashboard/app/settings.py"
	
	# Delete old symlinks
	rm -rf "$DLUQSREPO/NexusDashboard/app/luclient/res"
	rm -rf "$DLUQSREPO/NexusDashboard/app/luclient/locale"
	
	# Create necessary folders
	mkdir "$DLUQSREPO/NexusDashboard/app/luclient/res"
	
	# Create file links
	ln -sf "$CLIENTPATH/locale"              "$DLUQSREPO/NexusDashboard/app/luclient/locale"
	ln -sf "$CLIENTPATH/res/BrickModels"     "$DLUQSREPO/NexusDashboard/app/luclient/res/BrickModels"
	ln -sf "$CLIENTPATH/res/brickprimitives" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickprimitives"
	ln -sf "$CLIENTPATH/res/textures"        "$DLUQSREPO/NexusDashboard/app/luclient/res/textures"
	ln -sf "$CLIENTPATH/res/ui"              "$DLUQSREPO/NexusDashboard/app/luclient/res/ui"

	# TODO: review
	cp "$CLIENTPATH/res/brickdb.zip" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickdb.zip"

	# Create link to SQLite for nexus dashboard
	# CDServer will be created by the server on boot
	ln -sf "$DLUQSREPO/DarkflameServer/build/resServer/CDServer.sqlite" "$DLUQSREPO/NexusDashboard/app/luclient/res/cdclient.sqlite"
}

# Update configuration files with information unique to your specific server
function configure(){
	echo "WARNING: This script simplifies the configuration of your DLU server, but is NOT a replacement for good secret/password management or a secure database configuration. REMEMBER the passwords you use here"
	
	# Update the DB connection info
	dbconnect
	
	# Create the DB locally
	if [[ $HOSTCHOOSE != "y" && $HOSTCHOOSE != "Y" ]]; then
		echo "Installing local database server..."
		sudo apt-get update
		sudo apt-get install -y mariadb-server
	
		### CREATE DATABASE
		echo -e "Creating database..."
		sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DBNAME;"
		sudo mysql -u root -e "CREATE USER '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBPASS';"
		sudo mysql -u root -e "GRANT ALL ON $DBNAME . * TO '$DBUSER'@'$DBHOST';"
		sudo mysql -u root -e "FLUSH PRIVILEGES;"
	fi
	
	# Sanitize the DB password for use with sed
	# TODO: more things that will mess with sed replace: https://unix.stackexchange.com/questions/32907/what-characters-do-i-need-to-escape-when-using-sed-in-a-sh-script
	DBPASSSAN=`echo "$DBPASS" | sed -e 's/&/\\\&/g'`
	
	# Edit all the config files for each server with this information
	# This file won't exist until after a build
	sed -i 's/^mysql_host=.*$/mysql_host='"$DBHOST"'/g'         "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_database=.*$/mysql_database='"$DBNAME"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_username=.*$/mysql_username='"$DBUSER"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_password=.*$/mysql_password='"$DBPASSSAN"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"

	# Add database password in the Nexus Dashboard config
	# If you change the database name/database admin name, you'll need to manually change those
	sed -i 's/^DB_PASS=.*$/DB_PASS="'"$DBPASSSAN"'"/g' "$DLUQSREPO/config/nexusdashboard.py"
	sed -i 's/^DB_HOST=.*$/DB_HOST="'"$DBHOST"'"/g' "$DLUQSREPO/config/nexusdashboard.py"
	
	# Generate a random 32 character string for you. You're welcome.
	RANDOMSTRING=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`
	sed -i "s|APP_SECRET_KEY = \"\"|APP_SECRET_KEY = \"$RANDOMSTRING\"|g" "$DLUQSREPO/config/nexusdashboard.py"
	
	# Get DNS name for apache configuration
	read -p "Enter the DNS name of THIS server: " DOMAINNAME
	sed -i "s/ServerName your.domain.name/ServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu.conf"

	# Set external_ip based on DNS, or allow it manually
	read -p "Auto grab public IP from domain $DOMAINNAME? [y/n]: " IPCHOOSE
	if [[ $IPCHOOSE == "y" ]]; then
		EXTIP=`dig +short $DOMAINNAME | tail -n1`
	else
		read -p "Manually enter the public IP of the server:" EXTIP
	fi
	sed -i "s/^external_ip=localhost.*$/external_ip=$EXTIP/g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	
	# Set some slightly-more sane basic settings
	sed -i 's/^maximum_outgoing_bandwidth=.*$/maximum_outgoing_bandwidth='"$MAXBANDWIDTH"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^maximum_mtu_size=.*$/maximum_mtu_size='"$MAXMTU"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^solo_racing=.*$/solo_racing=1/g' "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
	
	# Auto generate a boot.cfg based on this domain information
	rm -f "$DLUQSREPO/config/boot.cfg"
	cp "$DLUQSREPO/config/custom.boot.cfg" "$DLUQSREPO/config/boot.cfg"
	sed -i "s/your.url/$DOMAINNAME/g" "$DLUQSREPO/config/boot.cfg"
	
	# link this as a place to download from in nexusdashboard
	# Accessible via 'https://your.url/static/boot.cfg'
	ln -sf "$DLUQSREPO/config/boot.cfg" "$DLUQSREPO/NexusDashboard/app/static/boot.cfg"
}

# You *could* just set gunicorn to export to 80, but by using apache as a proxy, it simplifies and standardizes other things, such as https
function installApache(){
	sudo apt-get install -y apache2 apache2-utils libexpat1 ssl-cert apache2-dev certbot python3-certbot-apache

	# Link included configuration file
	sudo ln -sf "$DLUQSREPO/config/dlu.conf" /etc/apache2/sites-available/dlu.conf

	# Disable default apache site
	sudo a2dissite 000-default default-ssl
	
	# Enable the proxy site
	sudo a2ensite dlu

	# Move a custom error page into position for sexier errors
	sudo mkdir -p /var/www/html/error
	# TODO POLISH: get the linking permissions right. Until then, just copy
	sudo cp "$DLUQSREPO/config/503.html" /var/www/html/error/503.html
	#sudo ln -f "$DLUQSREPO/config/503.html" /var/www/html/error/503.html
	
	# static assets for use by apache error pages
	sudo cp -r "$DLUQSREPO/NexusDashboard/app/static" /var/www/html/error/static
	#sudo ln -f "$DLUQSREPO/NexusDashboard/app/static"  /var/www/html/error/static

	sudo a2enmod proxy proxy_http rewrite ssl
	sudo systemctl restart apache2
	
	sudo certbot --apache
}

function initialize(){
	# Set up nexus dashboard and darkflameserver as systemd services
	OSUSER=`whoami`
	#mkdir -p ~/.config/systemd/user
	mkdir -p "/home/$OSUSER/.config/systemd/user"
	ln -sf "$DLUQSREPO/config/dlu.service"   "/home/$OSUSER/.config/systemd/user/dlu.service"
	ln -sf "$DLUQSREPO/config/nexus.service" "/home/$OSUSER/.config/systemd/user/nexus.service"
	
	# Change working directory in systemd service files to reflect wherever you installed DLUQuickstart
	sed -i 's|^WorkingDirectory=.*$|WorkingDirectory='"$DLUQSREPO"'/DarkflameServer/build/|g' "$DLUQSREPO/config/dlu.service"
	sed -i 's|^WorkingDirectory=.*$|WorkingDirectory='"$DLUQSREPO"'/NexusDashboard/|g' "$DLUQSREPO/config/nexus.service"
	# Get an absolute path to the MasterServer binary
	sed -i 's|^ExecStart=.*$|ExecStart='"$DLUQSREPO"'/DarkflameServer/build/MasterServer|g' "$DLUQSREPO/config/dlu.service"
	
	# Reload user's systemd services
	systemctl --user daemon-reload
	
	# Enable the services
	systemctl --user enable dlu.service
	systemctl --user enable nexus.service

	### Run the server and dashboard ###
	# This allows the proper file linking and database configuration
	
	systemctl --user start dlu.service
	sleep 60
	systemctl --user stop dlu.service

	# Ask if we need to create an admin account on the game server if the user needs one
	# Only do this for brand new servers
	echo -e "\n"
	read -p "Make a DLU admin account? [y/n]: " MAKEUSER
	if [[ $MAKEUSER == "y" ]]; then
		"$DLUQSREPO/DarkflameServer/build/MasterServer" -a
	fi

	# Upgrade database with columns necessary for Nexus Dashboard
	# TODO: ensure this actually has a reliable statefulness and doesn't cause problems
	cd "$DLUQSREPO/NexusDashboard/"
	flask db upgrade
	
	# Run NexusDashboard once to generate static css file used by the apache2 proxy
	# TODO: double check what else is in static/
	systemctl --user start nexus.service
	sleep 20
	systemctl --user stop nexus.service
}

### OPERATIONS FUNCTIONS ###
function buildServer() {
	updateSubmodules
	buildDLU
}

# It's recommended you shut down the server temporarily while you do this
function backUpDatabase(){
	dbconnect

	read -p "What should the backup be named? " BACKUPNAME
	mysqldump -h "$DBHOST" -u $DBUSER -p$DBPASS "$DBNAME" > "$DLUQSREPO/$BACKUPNAME"
	echo "Backup saved at $DLUQSREPO/$BACKUPNAME"
}

# Parse arguments in order
if [[ "$#" -gt 0 ]]; then 
	ITER=1

	until [[ "$ITER" -gt "$#" ]]
	do
		case "${!ITER}" in
			# Installation functions
			"--install")
				installDependencies
				;;
			"--configure")
				configure
				;;
			"--initialize")
				hookClient
				initialize
				;;
			"--install-proxy")
				installApache
				;;
			"-b"|"--backup")
				backUpDatabase
				;;
			# Ops functions
			"-k"|"--kill")
				systemctl --user stop dlu.service
				;;
			"-r"|"--run"|"--restart")
				systemctl --user stop dlu.service
				systemctl --user start dlu.service
				;;
			"-R"|"--recompile")
				systemctl --user stop dlu.service
				buildServer
				;;
			"-d"|"--dashboard")
				systemctl --user stop nexus.service
				systemctl --user start nexus.service
				;;
			"-dk"|"--dashboard-kill")
				systemctl --user stop nexus.service
				;;
			"-s"|"--status")
				systemctl --user status dlu.service
				systemctl --user status nexus.service
				;;
			*)
				;;
	esac

	ITER=$((ITER+1))
	done
else
	echo -e "ERROR: Please supply an argument!" 
	echo -e "INSTALLATION:"
	echo -e "\t- Install deps + compile: --install"
	echo -e "\t- Configure:              --configure"
	echo -e "\t- Complete install:       --initialize"
	echo -e "\t- Install Apache2 Proxy:  --install-proxy"
	echo -e "DLU SERVER OPS:"
	echo -e "\t- Kill server:            -k/--kill"
	echo -e "\t- Restart server:         -r/--restart"
	echo -e "\t- Recompile server:       -R/--recompile"
	echo -e "\t- Get server status:      -s/--status"
	echo -e "\t- Back up Database:       -b/--backup"
	echo -e "NEXUS DASHBOARD OPS:"
	echo -e "\t- Restart Dashboard:      -d/--dashboard"
	echo -e "\t- Kill Dashboard:         -dk/--dashboard-kill"
fi