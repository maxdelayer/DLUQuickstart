#!/bin/bash

# Where THIS repo is on your server's filesystem. Automatically detected
DLUQSREPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLIENTROOT="$DLUQSREPO/client"
DATABASENAME="DLU"

### INSTALLATION FUNCTIONS ###

# This grabs all the other repositories used (DarkFlameServer, NexusDashboard, and lcdr utils)
function updateSubmodules(){
	git pull
	git submodule update --init --recursive
	git submodule update --remote --merge
	#git submodule foreach git pull
}

# Build the server with your own settings. AKA, skip using build.sh
function buildDLU(){
	#echo -e "\n\nRunning build script..."
	#cd "$DLUQSREPO/DarkflameServer"
	#./build.sh
	
	mkdir -p "$DLUQSREPO/DarkflameServer/build"
	cd       "$DLUQSREPO/DarkflameServer/build"
	#make clean
	cmake ..
	make -j2 && ./MasterServer -m
}

function installDependencies(){
	# Update git repositories
	updateSubmodules
	
	# Install any other dependencies (via apt for debian-ish distros)
	sudo apt-get update
	sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar unzip sqlite libmagickwand-dev libssl-dev apache2 apache2-utils libexpat1 ssl-cert apache2-dev certbot python3-certbot-apache python3-flask

	### Install Nexus Dashboard dependencies
	pip3 install gunicorn
	pip3 install -r "$DLUQSREPO/NexusDashboard/requirements.txt"

	### CREATE DATABASE
	echo -e "Creating database..."
	echo "CREATE DATABASE IF NOT EXISTS $DATABASENAME;" | sudo mysql -u root
	
	sudo mysql -u root $DATABASENAME < "$DLUQSREPO/DarkflameServer/migrations/dlu/0_initial.sql"

	### Compile DLU
	buildDLU
}

function hookClient() {
	# Grab a lego universe client. If you have one, you can manually move it into place, if not, hey, check out this one I found
	CLIENTNAME="LEGO Universe (unpacked).rar"
	CLIENTLINK="https://archive.org/download/lego-universe-unpacked/$CLIENTNAME"
	# Only downloads if the file isn't already present
	if [[ ! -f "$CLIENTROOT/$CLIENTNAME" ]]; then
		wget "$CLIENTLINK" -P "$CLIENTROOT/"
		unrar x "$CLIENTROOT/$CLIENTNAME" "$CLIENTROOT/"
	fi
	
	### Link Nexus Dashboard
	ln -s "$DLUQSREPO/config/nexusdashboard.py" "$DLUQSREPO/NexusDashboard/app/settings.py"
	
	# Create necessary folders
	mkdir "$DLUQSREPO/NexusDashboard/app/luclient/res"
	mkdir "$DLUQSREPO/NexusDashboard/app/luclient/local"
	
	ln -s "$CLIENTROOT/locale"              "$DLUQSREPO/NexusDashboard/app/luclient/local/locale"
	ln -s "$CLIENTROOT/res/BrickModels"     "$DLUQSREPO/NexusDashboard/app/luclient/res/BrickModels"
	ln -s "$CLIENTROOT/res/brickprimitives" "$DLUQSREPO/NexusDashboard/app/luclient/res/brickprimitives"
	ln -s "$CLIENTROOT/res/textures"        "$DLUQSREPO/NexusDashboard/app/luclient/res/textures"
	ln -s "$CLIENTROOT/res/ui"              "$DLUQSREPO/NexusDashboard/app/luclient/res/ui"

	unzip "$CLIENTROOT/res/brickdb.zip" -d  "$DLUQSREPO/NexusDashboard/app/luclient/res/"

	### Link DLU Server
	ln -s "$CLIENTROOT/res/macros"              "$DLUQSREPO/DarkflameServer/build/res/macros"
	ln -s "$CLIENTROOT/res/BrickModels"         "$DLUQSREPO/DarkflameServer/build/res/BrickModels"
	ln -s "$CLIENTROOT/res/chatplus_en_us.txt"  "$DLUQSREPO/DarkflameServer/build/res/chatplus_en_us.txt"
	ln -s "$CLIENTROOT/res/chatminus_en_us.txt" "$DLUQSREPO/DarkflameServer/build/res/chatminus_en_us.txt"
	ln -s "$CLIENTROOT/res/names"               "$DLUQSREPO/DarkflameServer/build/res/names"
	ln -s "$CLIENTROOT/res/maps"                "$DLUQSREPO/DarkflameServer/build/res/maps"

	# Unzip navmeshes
	unzip "$DLUQSREPO/DarkflameServer/resources/navmeshes.zip" -d "$DLUQSREPO/DarkflameServer/build/res/maps/"

	# Link Locale file
	if ! [ -d "$DLUQSREPO/DarkflameServer/build/res/locale/" ]; then
		mkdir "$DLUQSREPO/DarkflameServer/build/res/locale/"
	fi
	ln -s "$CLIENTROOT/locale/locale.xml" "$DLUQSREPO/DarkflameServer/build/res/locale/locale.xml"

	# Convert fdb to sqlite
	python3 "$DLUQSREPO/utils/utils/fdb_to_sqlite.py" --sqlite_path "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite" "$CLIENTROOT/res/cdclient.fdb"

	ln -s "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite" "$DLUQSREPO/NexusDashboard/cdclient.sqlite"
	
	# Manual SQLITE migration running since the above has been inconsistent from my experience:
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/0_nt_footrace.sql"           | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/1_fix_overbuild_mission.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/2_script_component.sql"      | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/3_plunger_gun_fix.sql"       | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/4_nt_footrace_parrot.sql"    | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
}

# In development
function configureDatabase(){
	echo "WARNING: This script simplifies the configuration of your DLU server, but is NOT a replacement for good secret/password management or a secure MySQL configuration. REMEMBER the passwords you use here"
	
	MYSQLUSER="dluadmin"
	MYSQLPASS="fortheloveofallthatisgoodandholychangethispasswordbeforeyourunthis"
	MYSQLHOST="localhost"
	MYSQLDB="DLU"
	
	read -s -p "Enter the password for the newly created database user: " MYSQLPASS
	
	# Edit all the config files for each server with this information
	sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g"         "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
	sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g"   "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
	sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"
	sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/authconfig.ini"

	sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g"         "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
	sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g"   "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
	sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"
	sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/chatconfig.ini"

	sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g"         "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
	sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g"   "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
	sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"
	sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/worldconfig.ini"

	sed -i "s/^mysql_host=.*$/mysql_host=$MYSQLHOST/g"         "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
	sed -i "s/^mysql_database=.*$/mysql_database=$MYSQLDB/g"   "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
	sed -i "s/^mysql_username=.*$/mysql_username=$MYSQLUSER/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"
	sed -i "s/^mysql_password=.*$/mysql_password=$MYSQLPASS/g" "$DLUQSREPO/DarkflameServer/build/masterconfig.ini"

	# Create the database user
	echo "CREATE USER '$MYSQLUSER'@'$MYSQLHOST' IDENTIFIED WITH mysql_native_password BY '$MYSQLPASS';" | sudo mysql -u root 
	echo "GRANT ALL ON $MYSQLDB . * TO '$MYSQLUSER'@'$MYSQLHOST';" | sudo mysql -u root 
	echo "FLUSH PRIVILEGES;" | sudo mysql -u root 

	# Add database password in the Nexus Dashboard config
	# If you change the database name/etc., you'll need to manually change those
	sed -i "s|DB_PASS=\"pleasechangethis\"|DB_PASS=\"$MYSQLPASS\"|g" "$DLUQSREPO/config/nexusdashboard.py"
	
	echo -e "\n"
	read -p "Make an admin account? [y/n]: " MAKEUSER
	if [[ $MAKEUSER == "y" ]]; then
		cd "$DLUQSREPO/DarkflameServer/build/"
		./MasterServer -a
	fi
	
	# Generate random 32 character string for you. You're welcome.
	RANDOMSTRING=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`
	sed -i "s|APP_SECRET_KEY = \"\"|APP_SECRET_KEY = \"$RANDOMSTRING\"|g" "$DLUQSREPO/config/nexusdashboard.py"
	
	# Upgrade database with columns necessary for Nexus Dashboard
	cd "$DLUQSREPO/NexusDashboard/"
	flask db upgrade
	
	# Re-run any DLU server database migrations
	cd "$DLUQSREPO/DarkflameServer/build/"
	./MasterServer -m
}

# You *could* just set gunicorn to export to 80, but by using apache as a proxy, it simplifies and standardizes other things, such as https and dns
function installApache(){
	read -p "Enter the DNS name of the server: " DOMAINNAME

	sed -i "s/ServerName change.this.to.your.domain.name/ServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu-sites-available.conf"

	sudo ln -s "$DLUQSREPO/config/dlu.conf"          /etc/apache2/sites-available/dlu.conf
	sudo ln -s /etc/apache2/sites-available/dlu.conf /etc/apache2/sites-enabled/dlu.conf

	sudo a2enmod proxy proxy_http rewrite ssl
	sudo systemctl restart apache2
	
	sudo certbot --apache
}

### OPERATIONS FUNCTIONS ###

function runServer() {
	# You can't run MasterServer from just anywhere, or it can crash when trying to create logfiles
	cd "$DLUQSREPO/DarkflameServer/build/"
	sudo ./MasterServer &
}

function buildServer() {
	updateSubmodules
	buildDLU
}

function killServer() {
	MASTERPID=`ps -C 'MasterServer' -o pid=`
	if [[ $MASTERPID ]]; then
		sudo kill -9 $MASTERPID
		sleep 25
	fi
}

# Testing
function runDashboard() {
	cd "$DLUQSREPO/NexusDashboard/"
	gunicorn -b :8000 -w 4 wsgi:app &
}

# Testing
function killDashboard() {
	DASHPID=`ps -C 'gunicorn' -o pid=`
	if [[ $DASHPID ]]; then
		sudo kill -9 $DASHPID
		sleep 25
	fi
}

function backUpDatabase(){
	read -p "What should the backup be named?" BACKUPNAME
	sudo mysqldump "$DATABASENAME" > "$DLUQSREPO/$BACKUPNAME"
	echo "Backup saved at $DLUQSREPO/$BACKUPNAME"
}

# TODO; Polish input section
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
			"-b"|"--backup")
				backUpDatabase
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
				;;
			"--configure-database")
				configureDatabase
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
	echo -e "\t- Configure:             --configure-database"
	echo -e "\t- Install Apache2 Proxy: --install"
	echo -e "DLU SERVER OPERATIONS:"
	echo -e "\t- Kill server:           -k/--kill"
	echo -e "\t- Restart server:        -r/--restart"
	echo -e "\t- Recompile server:      -R/--recompile"
	echo -e "\t- Back up Database:      -b/--backup"
	echo -e "NEXUS DASHBOARD:"
	echo -e "\t- Restart Dashboard:     -d/--dashboard"
	echo -e "\t- Kill Dashboard:        -dk/--dashboard-kill"
fi
