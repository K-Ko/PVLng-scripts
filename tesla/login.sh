#!/bin/bash
USERNAME=$1
PASSWORD=$2
curl -c cookies.txt -d "user_session[email]=$USERNAME&user_session[password]=$PASSWORD" https://portal.vn.teslamotors.com/login
curl -b cookies.txt -c cookies.txt -H "Accept: application/json" https://portal.vn.teslamotors.com/vehicles
