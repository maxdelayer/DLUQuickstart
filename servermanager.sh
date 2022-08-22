#!/bin/bash

# Where THIS repo is on your server's filesystem. Automatically detected
DLUQSREPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CLIENTROOT="$DLUQSREPO/client/"
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
	cmake ..
	make -j2 && ./MasterServer -m
}

function installDependencies(){
	# Update git repositories
	updateSubmodules
	
	# Install any other dependencies (via apt for debian-ish distros)
	sudo apt-get update
	sudo apt-get install -y python3 python3-pip gcc cmake mysql-server zlib1g zlib1g-dev unrar unzip sqlite libmagickwand-dev libssl-dev apache2 apache2-utils libexpat1 ssl-cert apache2-dev

	### Install Nexus Dashboard dependencies
	pip3 install gunicorn
	pip3 install -r "$DLUQSREPO/NexusDashboard/requirements.txt"
	flask db upgrade

	### CREATE DATABASE
	echo -e "Creating database..."
	echo "CREATE DATABASE IF NOT EXISTS $DATABASENAME;" | sudo mysql -u root 

	### Compile DLU
	buildDLU
}

function hookClient() {
	### Link Nexus Dashboard
	ln -s "$CLIENTROOT/locale"              "$DLUQSREPO/NexusDashboard/app/luclient/locale"
	ln -s "$CLIENTROOT/res/BrickModels"     "$DLUQSREPO/NexusDashboard/app/luclient/BrickModels"
	ln -s "$CLIENTROOT/res/brickprimitives" "$DLUQSREPO/NexusDashboard/app/luclient/brickprimitives"
	ln -s "$CLIENTROOT/res/textures"        "$DLUQSREPO/NexusDashboard/app/luclient/textures"
	ln -s "$CLIENTROOT/res/ui"              "$DLUQSREPO/NexusDashboard/app/luclient/ui"

	unzip "$DLUQSREPO/NexusDashboard/brickdb.zip" -d "$DLUQSREPO/NexusDashboard/"

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

	# Re-run any database migrations
	"$DLUQSREPO/DarkflameServer/build/MasterServer" -m
	
	# Manual SQLITE migration running as a test:
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/0_nt_footrace.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/1_fix_overbuild_mission.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/2_script_component.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/3_plunger_gun_fix.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
	echo ".read $DLUQSREPO/DarkflameServer/migrations/cdserver/4_nt_footrace_parrot.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
}

# In development
function installApache(){
	#sudo cp -r "$DLUQSREPO/AccountManager/" /var/www/dlu/
	#sudo mv /var/www/dlu/app.py /var/www/dlu/dlu.py

	sed -i "s/ServerName change.this.to.your.domain.name/ServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu-sites-available.conf"

	sudo ln -s "$DLUQSREPO/config/dlu-sites-available.conf" /etc/apache2/sites-available/dlu.conf
	sudo ln -s /etc/apache2/sites-available/dlu.conf /etc/apache2/sites-enabled/dlu.conf

	sudo a2ensite "$DOMAINNAME"

	sudo a2enmod proxy
	sudo a2enmod proxy_http
	sudo a2enmod rewrite
	sudo a2enmod ssl
}

### OPERATIONS FUNCTIONS ###

function runServer() {
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
	gunicorn -b :8000 -w wsgi:app
}

# Not functional yet
function killDashboard() {
	exit
}

function backUpDatabase(){
	read -p "What should the backup be named?" BACKUPNAME
	sudo mysqldump "$DATABASENAME" > "$DLUQSREPO/$BACKUPNAME"
	echo "Backup saved at $DLUQSREPO/$BACKUPNAME"
}

# Get arguments
if [[ "$#" -gt 0 ]];then 
	ITER=1

	until [[ "$ITER" -gt "$#" ]]
	do
		case "${!ITER}" in
			"-r"|"--restart")
				killServer
				runServer
				;;
			"-R"|"--recompile")
				killServer
				buildServer
				runServer
				;;
			"-k"|"--kill")
				killServer
				;;
			"-b"|"--backup")
				backUpDatabase
				;;
			"--install")
				installDependencies
				hookClient
				;;
			*)
				;;
	esac

	ITER=$((ITER+1))
	done
else
	echo -e "ERROR: Please supply an argument!" 
	echo -e "INSTALLATION:"
	echo -e "\t- Install:          --install"
	echo -e "OPERATIONS:"
	echo -e "\t- Kill server:      -k/--kill"
	echo -e "\t- Restart server:   -r/--restart"
	echo -e "\t- Recompile server: -R/--recompile"
	echo -e "\t- Back up Database: -b/--backup"
fi
