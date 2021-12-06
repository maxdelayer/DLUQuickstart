#!/bin/bash

# Where the darkflame repo is
DLUQSREPO="/home/ubuntu/DLUQuickstart"



ln -s "$DLUQSREPO/client/client/res/chatplus_en_us.txt" "$DLUQSREPO/DarkflameServer/build/res/chatplus_en_us.txt"
ln -s "$DLUQSREPO/client/client/res/names" "$DLUQSREPO/DarkflameServer/build/res/names"

# Link Locale file
ln -s "$DLUQSREPO/client/client/res/locale/locale.xml" "$DLUQSREPO/DarkflameServer/build/res/locale/locale.xml"

echo -e "Done!"
