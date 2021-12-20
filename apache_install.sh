#!/bin/bash

# Attempting to set up an apache2 WSGI for the portal based on https://www.jakowicz.com/flask-apache-wsgi/

# Set this value to the domain where you're hosting
DOMAINNAME="your.domain.name"
DLUQSREPO="/home/ubuntu/DLUQuickstart"

sudo apt install -y apache2 apache2-utils libexpat1 ssl-cert libapache2-mod-wsgi

sudo cp -r "$DLUQSREPO/AccountManager/" /var/www/dlu/
sudo mv /var/www/dlu/app.py /var/www/dlu/dlu.py

sed -i "s/^\tServerName change.this.to.your.domain.name$/\tServerName $DOMAINNAME/g" "$DLUQSREPO/config/dlu-sites-available.conf"

sudo ln -s "$DLUQSREPO/config/dlu-sites-available.conf" /etc/apache2/sites-available/dlu.conf
sudo ln -s /etc/apache2/sites-available/dlu.conf /etc/apache2/sites-enabled/dlu.conf

sudo a2ensite "$DOMAINNAME"