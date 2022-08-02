#!/bin/bash

# Where the darkflame repo is
DLUQSREPO="/home/ubuntu/DLUQuickstart"

# Where the unpacked client files are located. This should be the directory where the 'res' folder is.
CLIENTROOT="$DLUQSREPO/client"

### Link Nexus Dashboard
ln -s "$CLIENTROOT/locale"              "$DLUQSREPO/NexusDashboard/app/luclient/locale"
ln -s "$CLIENTROOT/res/BrickModels"     "$DLUQSREPO/NexusDashboard/app/luclient/BrickModels"
ln -s "$CLIENTROOT/res/brickprimitives" "$DLUQSREPO/NexusDashboard/app/luclient/brickprimitives"
ln -s "$CLIENTROOT/res/textures"        "$DLUQSREPO/NexusDashboard/app/luclient/textures"
ln -s "$CLIENTROOT/res/ui"              "$DLUQSREPO/NexusDashboard/app/luclient/ui"

cp    "$CLIENTROOT/res/brickdb.zip" "$DLUQSREPO/NexusDashboard/brickdb.zip"
unzip "$DLUQSREPO/NexusDashboard/brickdb.zip"
rm    "$DLUQSREPO/NexusDashboard/brickdb.zip"

### Link DLU Server

ln -s "$CLIENTROOT/res/macros"              "$DLUQSREPO/DarkflameServer/build/res/macros"
ln -s "$CLIENTROOT/res/BrickModels"         "$DLUQSREPO/DarkflameServer/build/res/BrickModels"
ln -s "$CLIENTROOT/res/chatplus_en_us.txt"  "$DLUQSREPO/DarkflameServer/build/res/chatplus_en_us.txt"
ln -s "$CLIENTROOT/res/chatminus_en_us.txt" "$DLUQSREPO/DarkflameServer/build/res/chatminus_en_us.txt"
ln -s "$CLIENTROOT/res/names"               "$DLUQSREPO/DarkflameServer/build/res/names"
ln -s "$CLIENTROOT/res/maps"                "$DLUQSREPO/DarkflameServer/build/res/maps"

# Unzip navmeshes
unzip "$DLUQSREPO/DarkflameServer/resources/navmeshes.zip"
ln -s "$DLUQSREPO/DarkflameServer/resources/navmeshes" "$DLUQSREPO/DarkflameServer/build/res/maps/navmeshes"

# Link Locale file
if ! [ -d "$DLUQSREPO/DarkflameServer/build/res/locale/" ]; then
	mkdir "$DLUQSREPO/DarkflameServer/build/res/locale/"
fi
ln -s "$CLIENTROOT/locale/locale.xml" "$DLUQSREPO/DarkflameServer/build/res/locale/locale.xml"

# Convert fdb to sqlite
python3 "$DLUQSREPO/utils/utils/fdb_to_sqlite.py" --sqlite_path "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite" "$CLIENTROOT/res/cdclient.fdb"

ln -s "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite" "$DLUQSREPO/NexusDashboard/cdclient.sqlite":

# Re-run any database migrations
"$DLUQSREPO/build/MasterServer" -m

echo -e "Client linked!"
