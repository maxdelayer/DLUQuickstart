# Testing out if https://www.jakowicz.com/flask-apache-wsgi/ works

import sys
 
sys.path.append('/var/www/dlu')
 
from dlu import app as application