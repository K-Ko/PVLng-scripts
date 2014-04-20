#!/bin/bash
if test -z "$1" -o -z "$2" ; then
  echo You need to provide two arguments to $0
  echo "  1st your username as used in the mytesla web portal"
  echo "  2nd your passwort to the web portal"
  echo These are needed to create a cookie file which will then be used to login in the API
  echo Username and password will not be stored
  exit 1
fi

USERNAME=$1
PASSWORD=$2
if curl -c cookies.txt -d "user_session[email]=$USERNAME&user_session[password]=$PASSWORD" https://portal.vn.teslamotors.com/login ; then
  curl -b cookies.txt -c cookies.txt -H "Accept: application/json" https://portal.vn.teslamotors.com/vehicles
  echo You need the 'id' provided in the obove output for the tesla.conf file
fi
