#!/bin/bash

# Where THIS repo is on your server's filesystem. Automatically detected based on where this script is
DLUQSREPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLIENTROOT="$DLUQSREPO/client"

DBUSER="dluadmin"
DBPASS=""
DBHOST="localhost"
DBNAME="DLU"

function isScriptRoot(){
	if [[ $UID -ne 0 ]]; then
		echo "Cancelling: you must run this function as root"
		exit 1
	fi
}

### INSTALLATION FUNCTIONS ###

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

	# Potentially useful for secrets management in AWS
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
		unrar x "$CLIENTROOT/$CLIENTNAME" "$CLIENTROOT/"
	elif [[ ! -d "$CLIENTPATH" ]]
		# re-extract if the download was a success but the extraction failed
		unrar x "$CLIENTROOT/$CLIENTNAME" "$CLIENTROOT/"
	fi

	sed -i "s|^client_location=.*$|client_location=$CLIENTPATH/|g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"

	# Change config so that it doesn't launch authserver as root
	sed -i "s|^use_sudo_auth=.*$|use_sudo_auth=0|g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
	
	### Link Nexus Dashboard config
	ln -s "$DLUQSREPO/config/nexusdashboard.py" "$DLUQSREPO/NexusDashboard/app/settings.py"
	
	# Delete old symlinks
	rm -rf "$DLUQSREPO/NexusDashboard/app/luclient/res"
	rm -rf "$DLUQSREPO/NexusDashboard/app/luclient/locale"
	
	# Create necessary folders
	mkdir "$DLUQSREPO/NexusDashboard/app/luclient/res"
	
	# Create file links
	ln -s "$CLIENTPATH/locale"              "$DLUQSREPO/NexusDashboard/app/luclient/locale"
	ln -s "$CLIENTPATH/res/BrickModels"     "$DLUQSREPO/NexusDashboard/app/luclient/res/BrickModels"
	ln -s "$CLIENTPATH/res/brickprimitives" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickprimitives"
	ln -s "$CLIENTPATH/res/textures"        "$DLUQSREPO/NexusDashboard/app/luclient/res/textures"
	ln -s "$CLIENTPATH/res/ui"              "$DLUQSREPO/NexusDashboard/app/luclient/res/ui"

	# TODO: review
	cp "$CLIENTPATH/res/brickdb.zip" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickdb.zip"

	# Create link to SQLite for nexus dashboard
	# CDServer will be created by the server on boot
	ln -s "$DLUQSREPO/DarkflameServer/build/resServer/CDServer.sqlite" "$DLUQSREPO/NexusDashboard/app/luclient/res/cdclient.sqlite"
}

# In development
function configureDatabase(){
	echo "WARNING: This script simplifies the configuration of your DLU server, but is NOT a replacement for good secret/password management or a secure MySQL configuration. REMEMBER the passwords you use here"
	
	read -s -p "Enter the password for database user: " DBPASS
	echo -e "\n"
	read -p "Are you connecting to a remote database? [y/n]: " HOSTCHOOSE
	if [[ $HOSTCHOOSE == "y" || $HOSTCHOOSE == "Y" ]]; then
		read -p "Enter the hostname for database: " DBHOST
	else
		echo "Installing local database server..."
		sudo apt-get update
		sudo apt-get install mariadb-server
	
		### CREATE DATABASE
		echo -e "Creating database..."
		echo "CREATE DATABASE IF NOT EXISTS $DBNAME;" | sudo mysql -u root
		
		echo "CREATE USER '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBPASS';" | sudo mysql -u root 
		echo "GRANT ALL ON $DBNAME . * TO '$DBUSER'@'$DBHOST';" | sudo mysql -u root 
		echo "FLUSH PRIVILEGES;" | sudo mysql -u root
	fi
	
	# Edit all the config files for each server with this information
	sed -i "s/^mysql_host=.*$/mysql_host=$DBHOST/g"         "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i "s/^mysql_database=.*$/mysql_database=$DBNAME/g"   "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i "s/^mysql_username=.*$/mysql_username=$DBUSER/g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i "s/^mysql_password=.*$/mysql_password=$DBPASS/g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"

	# Add database password in the Nexus Dashboard config
	# If you change the database name/database admin name, you'll need to manually change those
	# TODO: do some input sanitization to prevent goofy things from happening with wacky characters. You may need to edit the database password manually in sharedconfig.ini and nexusdashboard.py
	sed -i "s/^DB_PASS=.*$/DB_PASS=\"$DBPASS\"/g" "$DLUQSREPO/config/nexusdashboard.py"
	sed -i "s/^DB_HOST=.*$/DB_HOST=\"$DBHOST\"/g" "$DLUQSREPO/config/nexusdashboard.py"
	
	# Generate random 32 character string for you. You're welcome.
	RANDOMSTRING=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`
	sed -i "s|APP_SECRET_KEY = \"\"|APP_SECRET_KEY = \"$RANDOMSTRING\"|g" "$DLUQSREPO/config/nexusdashboard.py"
	
	echo -e "\n"
	read -p "Make an admin account? [y/n]: " MAKEUSER
	if [[ $MAKEUSER == "y" ]]; then
		"$DLUQSREPO/DarkflameServer/build/MasterServer" -a
	fi
	
	# Get DNS name for apache configuration
	read -p "Enter the DNS name of the server: " DOMAINNAME
	sed -i "s/ServerName your.domain.name/ServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu.conf"

	# Set external_ip based on DNS, or allow it manually
	read -p "Auto grab public IP from domain $DOMAINNAME? [y/n]: " IPCHOOSE
	if [[ $IPCHOOSE == "y" ]]; then
		EXTIP=`dig +short $DOMAINNAME | tail -n1`
	else
		read -p "Manually enter the public IP of the server:" EXTIP
	fi
	sed -i "s/^external_ip=localhost.*$/external_ip=$EXTIP/g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
}

# You *could* just set gunicorn to export to 80, but by using apache as a proxy, it simplifies and standardizes other things, such as https
function installApache(){
	sudo apt-get install -y apache2 apache2-utils libexpat1 ssl-cert apache2-dev certbot python3-certbot-apache

	# Link included configuration file
	ln -s "$DLUQSREPO/config/dlu.conf" /etc/apache2/sites-available/dlu.conf

	# Disable default apache site
	sudo a2dissite 000-default default-ssl
	
	# Enable the proxy site
	sudo a2ensite dlu

	# Move error page into position for sexier errors
	mkdir -p /var/www/html/error
	cp "$DLUQSREPO/config/503.html" /var/www/html/error/503.html
	#ln -s "$DLUQSREPO/config/503.html" /var/www/html/error/503.html
	
	# Link static assets for use by apache error pages
	ln -s "$DLUQSREPO/NexusDashboard/app/static"  /var/www/html/error/static
	#cp -r "$DLUQSREPO/NexusDashboard/app/static" /var/www/html/error/static

	a2enmod proxy proxy_http rewrite ssl
	systemctl restart apache2
	
	certbot --apache
}


### OPERATIONS FUNCTIONS ###
function runServer() {
	"$DLUQSREPO/DarkflameServer/build/MasterServer" &
}

function buildServer() {
	updateSubmodules
	buildDLU
}

function killServer() {
	MASTERPID=`ps -C 'MasterServer' -o pid=`
	if [[ $MASTERPID ]]; then
		sudo kill -15 $MASTERPID
		echo "Waiting to ensure server is dead..."
		sleep 20
	fi
}

function runDashboard() {
	cd "$DLUQSREPO/NexusDashboard/"
	gunicorn -b :8000 -w 4 wsgi:app &
}

function killDashboard() {
	DASHPID=`ps -C 'gunicorn' -o pid=`
	if [[ $DASHPID ]]; then
		sudo kill -15 $DASHPID
		echo "Waiting to ensure dashboard is dead..."
		sleep 20
	fi
}

function initialize(){
	# A first run of the server will allow the right file linking and database configuration
	runServer
	sleep 60
	killServer

	# Upgrade database with columns necessary for Nexus Dashboard
	cd "$DLUQSREPO/NexusDashboard/"
	flask db upgrade
}

function backUpDatabase(){
	read -p "What should the backup be named? " BACKUPNAME
	mysqldump "$DBNAME" > "$DLUQSREPO/$BACKUPNAME"
	echo "Backup saved at $DLUQSREPO/$BACKUPNAME"
}

# Ensure script runs as root
#isScriptRoot

# Get arguments
if [[ "$#" -gt 0 ]];then 
	ITER=1

	until [[ "$ITER" -gt "$#" ]]
	do
		case "${!ITER}" in
			"-k"|"--kill")
				killServer
				;;
			"-r"|"--restart")
				killServer
				runServer
				;;
			"-R"|"--recompile")
				killServer
				buildServer
				runServer
				;;
			"-d"|"--dashboard")
				killDashboard
				runDashboard
				;;
			"-dk"|"--dashboard-kill")
				killDashboard
				;;
			"--install")
				installDependencies
				hookClient
				initialize
				;;
			"--configure")
				configureDatabase
				;;
			"--install-proxy")
				installApache
				;;
			"-b"|"--backup")
				backUpDatabase
				;;
			*)
				;;
	esac

	ITER=$((ITER+1))
	done
else
	echo -e "ERROR: Please supply an argument!" 
	echo -e "INSTALLATION:"
	echo -e "\t- Install DLU:           --install"
	echo -e "\t- Configure:             --configure"
	echo -e "\t- Install Apache2 Proxy: --install-proxy"
	echo -e "DLU SERVER OPS:"
	echo -e "\t- Kill server:           -k/--kill"
	echo -e "\t- Restart server:        -r/--restart"
	echo -e "\t- Recompile server:      -R/--recompile"
	echo -e "\t- Back up Database:      -b/--backup"
	echo -e "NEXUS DASHBOARD OPS:"
	echo -e "\t- Restart Dashboard:     -d/--dashboard"
	echo -e "\t- Kill Dashboard:        -dk/--dashboard-kill"
fi