#!/bin/bash

# Where THIS repo is on your server's filesystem. Automatically detected based on where this script is
DLUQSREPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLIENTROOT="$DLUQSREPO/client"

### Global variables for database login info
# User and database are sane defaults I've decided upon, and
DBUSER="dluadmin"
DBNAME="DLU"
# The host and password are asked for on runtime, when needed
DBPASS=""
DBHOST="localhost"

CONFIGFILENAME=""
IMPORTFILE=""
CLIENTPATH=""

### INSTALLATION FUNCTIONS ###
# Build the server and flag binaries properly
function buildDLU(){
	cd "$DLUQSREPO/DarkflameServer"
	./build.sh
	
	# Make it so authserver can use port 1001 without sudo
	if [ -e "$DLUQSREPO/DarkflameServer/build/AuthServer" ]; then
		sudo setcap 'cap_net_bind_service=+ep' "$DLUQSREPO/DarkflameServer/build/AuthServer"
	fi
}

# This updates all the other repositories used (DarkFlameServer & NexusDashboard)
function updateSubmodules(){
	git pull
	
	#if [ -z `ls "$DLUQSREPO/DarkflameServer/" | head -n 1` ]; then
	#	git submodule update --init --recursive
	#fi
	
	git submodule update --init --recursive --remote --merge
}

# Makes sure jq is installed
function installjq(){
	# Check first that jq isn't installed before installing
	if ! command -v jq &> /dev/null; then
		sudo apt-get update
		sudo apt-get install -y jq
	fi
}

# Installs basic stuff
function installDependencies(){
	# Update git repositories
	updateSubmodules
	
	# Install any other dependencies (via apt for debian-ish distros)
	sudo apt-get update
	sudo apt-get install -y python3 python3-pip python3-full python3-venv gcc cmake zlib1g zlib1g-dev unrar unzip libmagickwand-dev libssl-dev mariadb-client jq
	
	# Potentially useful for secrets management in AWS down the line
	#apt-get install -y awscli

	### Install Nexus Dashboard dependencies
	# Install python dependencies in a python virtual environment
	if [ ! -d "$DLUQSREPO/.venv" ]; then
		python3 -m venv "$DLUQSREPO/.venv"
	fi
	source "$DLUQSREPO/.venv/bin/activate"
	pip3 install -r "$DLUQSREPO/NexusDashboard/requirements.txt" | grep -v 'already satisfied'
	deactivate
	
	### Compile DLU
	buildDLU
}

function downloadClient() {
	# Grab a lego universe client. If you have one, you can manually move it into place, if not, hey, check out this one I found:
	CLIENTLINK="https://archive.org/download/lego-universe-unpacked/LEGO Universe (unpacked).rar"
	CLIENTNAME="LEGO Universe (unpacked).rar"
	# NexusDashboard needs an unpacked client to work properly, so we use one of those
	
	# Link client location
	# If you're downloading a different client link, you'll probably need to change this. The 'res' folder should be in this directory
	CLIENTPATH="$CLIENTROOT"
	
	# Only downloads if the file isn't already present
	if [[ ! -f "$CLIENTPATH/$CLIENTNAME" ]]; then
		wget "$CLIENTLINK" -P "$CLIENTPATH/"
	fi
}

function extractClient() {
	# Only extract if the folders we're expecting from extraction isn't there
	if [[ ! -d "$CLIENTPATH/res/" ]]; then
		unrar x "$CLIENTPATH/$CLIENTNAME" "$CLIENTPATH/" -x@"$CLIENTPATH/exclude.txt"
		# Using `-x@filename.txt` to exclude files that the server doesn't actually need
		# This saves just over 10gb of space lol
		
		# If we have just done an extraction, then the sqlite file will be 'fresh' and we need to run migrations again the next time the MasterServer starts
		# MasterServer does this if there aren't references that it's been run before in the database
		
		# Check if the table exists before trying to delete stuff from it
		# Prevents an error on first run of a new database
		TABLEEXISTS="`mysql -Ns -u "$DBUSER" -D "$DBNAME" -h "$DBHOST" -p"$DBPASS" -e 'SHOW TABLES LIKE "migration_history"'`"
		if [[ "$TABLEEXISTS" == "migration_history" ]]; then
			# Remove references to old sqlite migrations that may not be valid anymore
			mysql -u $DBUSER -D $DBNAME -h $DBHOST -p$DBPASS -e "DELETE FROM migration_history WHERE name LIKE 'cdserver/%'"
		fi
	fi
}

# References DB variables
function hookClient() {
	downloadClient

	extractClient

	# Set client location in config
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

	# unzip brickdb into the correct place
	unzip -q "$CLIENTPATH/res/brickdb.zip" -d "$DLUQSREPO/NexusDashboard/app/luclient/res/"
	# copy the zip anyways since otherwise it will freak out
	cp "$CLIENTPATH/res/brickdb.zip" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickdb.zip"

	# Create link to SQLite for nexus dashboard
	# CDServer will be created by the server on boot
	ln -sf "$DLUQSREPO/DarkflameServer/build/resServer/CDServer.sqlite" "$DLUQSREPO/NexusDashboard/app/luclient/res/cdclient.sqlite"
}

# References CONFIGFILENAME
# Update configuration files with information unique to your specific server
function configure(){
	# Create the DB locally
	if [ "$DBHOST" == "localhost" ]; then
		echo "Installing local database server..."
		sudo apt-get update
		sudo apt-get install -y mariadb-server
	
		### CREATE DATABASE
		# Only create databse if it doesn't exist
		DBEXISTS="`sudo mysql -Ns -u root -e "SHOW DATABASES LIKE 'DLU'"`"
		if [[ ! "$DBEXISTS" == "DLU" ]]; then
			echo -e "Creating database..."
			sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DBNAME;"
			sudo mysql -u root -e "CREATE USER '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBPASS';"
			sudo mysql -u root -e "GRANT ALL ON $DBNAME . * TO '$DBUSER'@'$DBHOST';"
			sudo mysql -u root -e "FLUSH PRIVILEGES;"
		else
			echo "Updating database user password..."
			# Database exists, but lets update the password of the user
			sudo mysql -u root -e "ALTER USER '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBPASS';"
			sudo mysql -u root -e "FLUSH PRIVILEGES;"
		fi
	fi
	
	# Sanitize the DB password for use with sed
	# TODO: more things that will mess with sed replace: https://unix.stackexchange.com/questions/32907/what-characters-do-i-need-to-escape-when-using-sed-in-a-sh-script
	DBPASSSAN="`echo "$DBPASS" | sed -e 's/&/\\\&/g'`"
	
	# Edit all the config files for each server with this information
	# This file won't exist until after a build
	sed -i 's/^mysql_host=.*$/mysql_host='"$DBHOST"'/g'         "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_database=.*$/mysql_database='"$DBNAME"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_username=.*$/mysql_username='"$DBUSER"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	sed -i 's/^mysql_password=.*$/mysql_password='"$DBPASSSAN"'/g' "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"

	# Add database password in the Nexus Dashboard config
	# If you change the database name/database admin user name, you'll need to manually change those
	sed -i 's/^DB_PASS=.*$/DB_PASS="'"$DBPASSSAN"'"/g' "$DLUQSREPO/config/nexusdashboard.py"
	sed -i 's/^DB_HOST=.*$/DB_HOST="'"$DBHOST"'"/g' "$DLUQSREPO/config/nexusdashboard.py"
	
	# Generate a random 32 character string for you. You're welcome.
	RANDOMSTRING="`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`"
	sed -i "s|APP_SECRET_KEY = \"\"|APP_SECRET_KEY = \"$RANDOMSTRING\"|g" "$DLUQSREPO/config/nexusdashboard.py"
	
	# Get DNS name for apache configuration
	DOMAINNAME="$SERVHOST"
	
	# Grab the IP automatically if it wasn't specified
	if [ "$SERVIP" == "null" ]; then
		# TODO: can external_ip just be the domain given localhost works? what makes the most sense long-term?
		EXTIP="`dig +short $DOMAINNAME | tail -n1`"
	fi
	sed -i "s/^external_ip=.*$/external_ip=$EXTIP/g" "$DLUQSREPO/DarkflameServer/build/sharedconfig.ini"
	
	# Put the domain in the apache config file
	sed -i "s/ServerName your.domain.name/ServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu.conf"
	
	# Auto generate a boot.cfg based on this domain information
	rm -f "$DLUQSREPO/config/boot.cfg"
	cp "$DLUQSREPO/config/custom.boot.cfg" "$DLUQSREPO/config/boot.cfg"
	sed -i "s/your.url/$DOMAINNAME/g" "$DLUQSREPO/config/boot.cfg"
	
	# Put the server's human-readable name in the boot.cfg
	sed -i "s/^SERVERNAME=0:.*$/SERVERNAME=0:$SERVNAME/g" "$DLUQSREPO/config/boot.cfg"
	
	# link this as a place to download from in nexusdashboard
	# Accessible via 'https://your.url/static/boot.cfg'
	ln -sf "$DLUQSREPO/config/boot.cfg" "$DLUQSREPO/NexusDashboard/app/static/boot.cfg"
	
	# Set any other settings specified in the DLUQuickstart configuration file
	if [[ -f "$CONFIGFILENAME" ]]; then
		echo -e "\nLoading custom settings:"
		NUMCONFIGS=`jq '.server.config | length' "$CONFIGFILENAME"`
		
		for CONFNUM in $(seq 0 $((NUMCONFIGS - 1))); do
			CONFIGFILE=`jq -r ".server.config[$CONFNUM].file" "$CONFIGFILENAME"`
			CONFIGSETTING=`jq -r ".server.config[$CONFNUM].setting" "$CONFIGFILENAME"`
			CONFIGVALUE=`jq -r ".server.config[$CONFNUM].value" "$CONFIGFILENAME"`
			
			# We can make some assumptions about where the files are for simplicity's sake
			if [[ "$CONFIGFILE" == "settings.py" ]]; then
				CONFIGPATH="$DLUQSREPO/NexusDashboard/app"
			else
				CONFIGPATH="$DLUQSREPO/DarkflameServer/build"
			fi
			
			sed -i "s|^$CONFIGSETTING\s*=.*$|$CONFIGSETTING=$CONFIGVALUE|g" "$CONFIGPATH/$CONFIGFILE"
			
			# If you can't find what we tried to search and replace (IE: there was no original setting there to update) then just append to the config file
			if ! grep -q "$CONFIGSETTING=$CONFIGVALUE" "$CONFIGPATH/$CONFIGFILE"; then
				echo -e "\n$CONFIGSETTING=$CONFIGVALUE" >> "$CONFIGPATH/$CONFIGFILE"
				echo "Added '$CONFIGSETTING=$CONFIGVALUE' to '$CONFIGFILE'"
			else
				echo "Set '$CONFIGSETTING=$CONFIGVALUE' in '$CONFIGFILE'"
			fi
		done
	fi
}

# You *could* just set gunicorn to export to 80, but by using apache as a proxy, it simplifies and standardizes other things, such as https
function installApache(){
	# Don't do all this if it's local install
	if [ "$SERVHOST" != "localhost" ]; then
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
		
		# Run NexusDashboard once to generate static css file used by the apache2 proxy
		sudo systemctl start nexus.service
		sleep 10
		# Do a curl to make sure the page is rendered once
		curl 127.0.0.1:8000 > /dev/null
		sleep 10
		sudo systemctl stop nexus.service
		
		# Static assets for use by apache error pages
		sudo cp -r "$DLUQSREPO/NexusDashboard/app/static" /var/www/html/error/static
		
		# Remove unnecessary static files
		sudo rm -rf /var/www/html/error/static/.webassets-cache/
		
		sudo a2enmod proxy proxy_http rewrite ssl
		sudo systemctl restart apache2
		
		if [ "$SSLEMAIL" == "null" ]; then
			# If the email isn't specified in the config file, get the cert in interactive mode
			sudo certbot --apache --domains "$SERVHOST" --agree-tos
		else
			# Having the email in the file lets you do this noninteractively
			sudo certbot -n --apache --domains "$SERVHOST" --agree-tos --email $SSLEMAIL
		fi
	fi
}

# References IMPORTFILE
function initialize(){
	# Set up nexus dashboard and darkflameserver as systemd services
	# This lets them be easily managed through a common interface
	sudo ln -sf "$DLUQSREPO/config/dlu.service"   "/etc/systemd/system/dlu.service"
	sudo ln -sf "$DLUQSREPO/config/nexus.service" "/etc/systemd/system/nexus.service"
	
	# Change working directory in systemd service files to reflect wherever you installed DLUQuickstart
	sed -i 's|^WorkingDirectory=.*$|WorkingDirectory='"$DLUQSREPO"'/DarkflameServer/build/|g' "$DLUQSREPO/config/dlu.service"
	sed -i 's|^WorkingDirectory=.*$|WorkingDirectory='"$DLUQSREPO"'/NexusDashboard/|g' "$DLUQSREPO/config/nexus.service"
	# Get an absolute path to the MasterServer binary
	sed -i 's|^ExecStart=.*$|ExecStart='"$DLUQSREPO"'/DarkflameServer/build/MasterServer|g' "$DLUQSREPO/config/dlu.service"
	# Use the python3 virtualenv to run Nexus Dashboard
	sed -i 's|^ExecStart=.*$|ExecStart='"$DLUQSREPO"'/.venv/bin/python3 -m gunicorn -b :8000 -w 4 wsgi:app |g' "$DLUQSREPO/config/nexus.service"
	
	# Set the user to be the current user
	# If you're using a service account, make sure you run servermanager.sh as the service account
	OSUSER="`whoami`"
	sed -i 's|^User=.*$|User='"$OSUSER"'|g' "$DLUQSREPO/config/dlu.service"
	sed -i 's|^User=.*$|User='"$OSUSER"'|g' "$DLUQSREPO/config/nexus.service"
	
	# Reload user's systemd services
	sudo systemctl daemon-reload
	
	# Enable the services
	sudo systemctl enable dlu.service
	sudo systemctl enable nexus.service

	### Run the server and dashboard ###
	# This allows the proper file linking and database configuration
	echo "Running the server to let it initialize things"
	sudo systemctl start dlu.service
	sleep 120
	sudo systemctl stop dlu.service

	# Upgrade database with columns necessary for Nexus Dashboard
	# TODO: ensure this actually has a reliable statefulness and doesn't cause problems
	cd "$DLUQSREPO/NexusDashboard/"
	flask db upgrade

	# Create admin user or import database with existing admin user
	if [[ "$IMPORTFILE" == "null" ]]; then
		# This is only done on brand new servers
		echo "Creating an admin account the new DLU Server:"
		"$DLUQSREPO/DarkflameServer/build/MasterServer" -a
		# Write the import as "COMPLETED" to the config file so it knows there is an admin user
		jq --arg arg "COMPLETED" '.server.db.import = $arg' "$CONFIGFILENAME" > "$CONFIGFILENAME.tmp"
		mv "$CONFIGFILENAME.tmp" "$CONFIGFILENAME"
	else
		# Only import if it hasn't been marked as completed
		if [[ ! "$IMPORTFILE" == "COMPLETED" ]]; then
			# Make sure the file exists
			if [ -f "$DLUQSREPO/$IMPORTFILE" ]; then
				# Import the file
				echo "Importing database file '$IMPORTFILE' (this may take some time)"
				mysql -u $DBUSER -D $DBNAME -h $DBHOST -p$DBPASS < "$DLUQSREPO/$IMPORTFILE"
				
				# Mark import complete
				echo "Marking import as complete"
				jq --arg arg "COMPLETED" '.server.db.import = $arg' "$CONFIGFILENAME" > "$CONFIGFILENAME.tmp"
				mv "$CONFIGFILENAME.tmp" "$CONFIGFILENAME"
				echo "Import marked complete"
				jq '.' "$CONFIGFILENAME"
			fi
		fi
	fi
}

### CONFIGURATION FUNCTION ###

# Generate a configuration file by asking all the questions in the script
function genConfig() {
	# Put all this in a file
	read -p "Name of the file to save config to: " CONFIGFILENAME
	
	# Default json contains warning information to tell people to not be idiots
	CONFIGJSON='{ "WARNING": { "READ ME": "This configuration file can contain sensitive information", "BEWARE": "DO NOT SHARE THIS CONFIGURATION FILE WITH ANYONE" }, "server": {} }'
	
	# Get the server name
	read -p "Name of your DLU server: " SERVNAME
	CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$SERVNAME" '.server.name = $arg'`
	
	# Get the server type
	echo -e "\nThere are two types of DLU servers:"
	echo "1. LOCAL server, which is for offline solo play"
	echo "2. INTERNET servers, which is for hosting on the public internet"
	echo -e "Note: Local servers (option #1) are recommended for most users\n"
	SERVTYPE=0
	while [ "$SERVTYPE" != 1 ] && [ "$SERVTYPE" != 2 ]; do
		read -p "Type of server (1 or 2): " SERVTYPE
		if [ "$SERVTYPE" != 1 ] && [ "$SERVTYPE" != 2 ]; then
			echo "ERROR: Invalid input! Valid options are 1 for local and 2 for internet"
		fi
	done
	
	# Check if they are importing an existing server's database
	if [ $SERVTYPE -eq 1 ] ; then
		# If type is local:		
		# Set DNS to localhost
		CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "localhost" '.server.network.domain = $arg'`

		# Set DB to localhost
		CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "localhost" '.server.db.host = $arg'`
		
		# Add sane default of solo racing
		CONFIGJSON=`echo "$CONFIGJSON" | jq --argjson arg '{"file": "worldconfig.ini","setting": "solo_racing","value": "1"}' '.server.config += [$arg]'`
	else
		# If type is internet:
		# Ask about DNS and IP
		echo -e "\n"
		read -p "Enter the DNS name of THIS server: " DOMAINNAME
		CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$DOMAINNAME" '.server.network.domain = $arg'`
		
		# Set external_ip based on DNS, or allow it manually
		read -p "Auto grab public IP from domain $DOMAINNAME? [y/n]: " IPCHOOSE
		if [[ ! "$IPCHOOSE" == "y" ]]; then
			read -p "Enter the public IP of the server: " EXTIP
			CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$EXTIP" '.server.network.ip = $arg'`
		fi
		
		# Ask about Let's Encrypt information
		echo -e "\nTo install an SSL cert, Let's Encrypt requires an email to give alerts when certs expire"
		echo "1. Let certbot ask me for this during the installation"
		echo "2. Save this email to the configuration file (Optional)"
		echo -e "Note: Saving this to the file isn't necessary, but will automate more of the install\n"
		SSLTYPE=0
		while [ "$SSLTYPE" != 1 ] && [ "$SSLTYPE" != 2 ]; do
			read -p "SSL Renewal email decision (1 or 2): " SSLTYPE
			if [ "$SSLTYPE" != 1 ] && [ "$SSLTYPE" != 2 ]; then
				echo "ERROR: Invalid input! Valid options are 1 or 2"
			fi
		done
		if [ $SSLTYPE -eq 2 ] ; then
			read -p "Enter the email that lets encrypt will send alerts to: " RENEWALEMAIL
			CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$RENEWALEMAIL" '.server.network.certbot_email = $arg'`
		fi
		
		# Ask about DB being local or remote
		echo -e "\nThere are two types of database installs:"
		echo "1. LOCAL database, which installs on this machine"
		echo "2. REMOTE database, which connects to an existing database on a different machine"
		echo -e "Note: Local database (option #1) is recommended for most users\n"
		while [ "$DBTYPE" != 1 ] && [ "$DBTYPE" != 2 ]; do
			read -p "Type of Database (1 or 2): " DBTYPE
			if [ "$DBTYPE" != 1 ] && [ "$DBTYPE" != 2 ]; then
				echo "ERROR: Invalid input! Valid options are 1 for LOCAL and 2 for REMOTE"
			fi
		done
		
		# Set up the database options
		if [ $DBTYPE -eq 2 ] ; then
			# If remote, ask for domain and password info for connection
			read -p "Enter the DNS name of the remote database: " DBURL
			CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$DBURL" '.server.db.host = $arg'`
			
			read -s -p "Enter the password for the database user: " DBPASS
			CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "$DBPASS" '.server.db.password = $arg'`
		else
			# If local, set DB to localhost
			CONFIGJSON=`echo "$CONFIGJSON" | jq --arg arg "localhost" '.server.db.host = $arg'`
		fi
		
		# Add empty default config section
		CONFIGJSON=`echo "$CONFIGJSON" | jq '.server.config += []'`
	fi
	
	# Add sane network defaults
	CONFIGJSON=`echo "$CONFIGJSON" | jq --argjson arg '{"file": "sharedconfig.ini","setting": "maximum_outgoing_bandwidth","value": "0"}' '.server.config += [$arg]'`
	CONFIGJSON=`echo "$CONFIGJSON" | jq --argjson arg '{"file": "sharedconfig.ini","setting": "maximum_mtu_size","value": "768"}' '.server.config += [$arg]'`
	
	# Ask about database import
	echo -e "\n"
	read -p "Do you have a pre-existing database file to import? [y/n]: " DBIMPORT
	if [[ "$DBIMPORT" == "y" ]]; then		
		# If import, ask for file name
		read -p "Enter the name of the database file to import: " DBFILE
		CONFIGJSON=`echo $CONFIGJSON | jq --arg arg "$DBFILE" '.server.db.import = $arg'`
	fi
	
	# Save the server config info to file
	echo -e "\nWriting config to '$CONFIGFILENAME'"
	echo "$CONFIGJSON" | jq '.' > "$CONFIGFILENAME"
}

# Full server install based on config file
function parseConfig() {
	# TODO: check for existing installation? make each installation step detect that it was done and add to the config
	echo "Loading configuration from file '$CONFIGFILENAME'..."
	if [ -f "$CONFIGFILENAME" ]; then		
		SERVNAME=`jq -r '.server.name' "$CONFIGFILENAME"`
		
		SERVHOST=`jq -r '.server.network.domain' "$CONFIGFILENAME"`
		SERVIP=`jq -r '.server.network.ip' "$CONFIGFILENAME"`
		
		SSLEMAIL=`jq -r '.server.network.certbot_email' "$CONFIGFILENAME"`
		
		DBHOST=`jq -r '.server.db.host' "$CONFIGFILENAME"`
		DBPASS=`jq -r '.server.db.password' "$CONFIGFILENAME"`
		if [ "$DBPASS" = "null" ]; then
			# If DB password isn't specified, generate one randomly
			DBPASS="`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`"
			
			# Save the generated password to the json in the file
			jq --arg arg "$DBPASS" '.server.db.password = $arg' "$CONFIGFILENAME" > "$CONFIGFILENAME.tmp"
			mv "$CONFIGFILENAME.tmp" "$CONFIGFILENAME"
		fi
		
		IMPORTFILE=`jq -r '.server.db.import' "$CONFIGFILENAME"`
	else
		echo "ERROR: file '$CONFIGFILENAME' not found"
	fi
}

# Query user for, then read, the config file
function askConfig(){
	read -p "What config file should be used?" CONFIGFILENAME
	parseConfig
}

### OPERATIONS FUNCTIONS ###
function buildServer() {
	updateSubmodules
	buildDLU
}

# It's recommended you shut down the server temporarily while you do this
function backUpDatabase(){
	askConfig

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
			# Generate config
			"-g"|"--generate-config")
				installjq
			
				genConfig
				
				# Exit script after this
				break
				;;
			# Installation functions

			"--pre-bake")
				# These are the two longest times of the install - but can be done ahead of time regardless of one's configuration
				installDependencies
				downloadClient
				
				# Exit script after this
				break
				;;
			"--install")
				# Check next value for file name
				ITER=$((ITER + 1))	
				CONFIGFILENAME="${!ITER}"
				
				if [ -f "$CONFIGFILENAME" ]; then
					installjq
					
					parseConfig
					
					# Run setup steps
					installDependencies
					configure
					hookClient
					initialize
					installApache
				elif [ -z "$CONFIGFILENAME" ]; then
					echo "ERROR: Configuration file not specified"
				else
					echo "ERROR: Configuration file '$CONFIGFILENAME' not found"
				fi
				
				# Exit script after this
				break
				;;
			"--configure")
				ITER=$((ITER + 1))
				CONFIGFILENAME="${!ITER}"
				
				if [ -f "$CONFIGFILENAME" ]; then
					installjq
					
					parseConfig
					configure
				elif [ -z "$CONFIGFILENAME" ]; then
					echo "ERROR: Configuration file not specified"
				else
					echo "ERROR: Configuration file '$CONFIGFILENAME' not found"
				fi
				
				break
				;;
			"-b"|"--backup")
				backUpDatabase
				;;
			# Ops functions
			"-k"|"--kill")
				sudo systemctl stop dlu.service
				;;
			"-r"|"--run"|"--restart")
				sudo systemctl stop dlu.service
				sudo systemctl start dlu.service
				;;
			"-R"|"--recompile")
				sudo systemctl stop dlu.service
				buildServer
				;;
			"-d"|"--dashboard")
				sudo systemctl stop nexus.service
				sudo systemctl start nexus.service
				;;
			"-dk"|"--dashboard-kill")
				sudo systemctl stop nexus.service
				;;
			"-s"|"--status")
				sudo systemctl status dlu.service
				sudo systemctl status nexus.service
				;;
			*)
				;;
	esac

	ITER=$((ITER+1))
	done
else
	echo -e "ERROR: Please supply an argument!" 
	echo -e "INSTALLATION:"
	echo -e "\t- Generate config file:     -g/--generate"
	echo -e "\t- Install from config file: --install [file]"
	echo -e "\t- Reapply config to server: --configure [file]"
	echo -e "\t- Pre-download necessary files: --pre-bake"
	echo -e "DLU SERVER OPS:"
	echo -e "\t- Stop server:       -k/--kill"
	echo -e "\t- Restart server:    -r/--restart"
	echo -e "\t- Recompile server:  -R/--recompile"
	echo -e "\t- Get server status: -s/--status"
	echo -e "\t- Back up database:  -b/--backup"
	echo -e "NEXUS DASHBOARD OPS:"
	echo -e "\t- Restart Dashboard: -d/--dashboard"
	echo -e "\t- Kill Dashboard:    -dk/--dashboard-kill"
fi