#!/bin/bash

# IMPORTANT: Change this value to the home directory of DLUQuickstart!
DLUDirectory="/home/ubuntu/DLUQuickstart"

function runServer() {
	cd $DLUDirectory/DarkflameServer/build/
	sudo ./MasterServer &
}

function buildServer() {
	cd $DLUDirectory/DarkflameServer/
	git pull
	./build.sh
}

function killServer() {
	MASTERPID=`ps -C 'MasterServer' -o pid=`
	sudo kill -9 $MASTERPID
	sleep 15
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
			*)
				;;
	esac

	ITER=$((ITER+1))
	done
else
	echo -e "\n\tERROR: Please supply an argument!" 
	echo -e "\n\t\tKill server: -k/--kill"
	echo -e "\n\t\tRestart server: -r/--restart"
	echo -e "\n\t\tRecompile server: -R/--recompile"
fi