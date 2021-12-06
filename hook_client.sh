#!/bin/bash

# Where the darkflame repo is
DLUQSREPO="/home/ubuntu/DLUQuickstart"

# Where the unpacked client files are located. This should be the directory where the 'res' folder is.
CLIENTROOT="$DLUQSREPO/client"

ln -s "$CLIENTROOT/res/macros"             "$DLUQSREPO/DarkflameServer/build/res/macros"
ln -s "$CLIENTROOT/res/BrickModels"        "$DLUQSREPO/DarkflameServer/build/res/BrickModels"
ln -s "$CLIENTROOT/res/chatplus_en_us.txt" "$DLUQSREPO/DarkflameServer/build/res/chatplus_en_us.txt"
ln -s "$CLIENTROOT/res/names"              "$DLUQSREPO/DarkflameServer/build/res/names"
ln -s "$CLIENTROOT/res/maps"               "$DLUQSREPO/DarkflameServer/build/res/maps"

# Link Locale file
if ! [ -d "$DLUQSREPO/DarkflameServer/build/res/locale/" ]; then
	mkdir "$DLUQSREPO/DarkflameServer/build/res/locale/"
fi
ln -s "$CLIENTROOT/locale/locale.xml" "$DLUQSREPO/DarkflameServer/build/res/locale/locale.xml"

python3 "$DLUQSREPO/utils/utils/fdb_to_sqlite.py" --sqlite_path "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite" "$CLIENTROOT/res/cdclient.fdb"

# Extra transactions to fix game breaking bugs
cat "$DLUQSREPO/DarkflameServer/migrations/cdserver/0_nt_footrace.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
cat "$DLUQSREPO/DarkflameServer/migrations/cdserver/1_fix_overbuild_mission.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"
cat "$DLUQSREPO/DarkflameServer/migrations/cdserver/2_script_component.sql" | sqlite3 "$DLUQSREPO/DarkflameServer/build/res/CDServer.sqlite"

echo -e "Done!"