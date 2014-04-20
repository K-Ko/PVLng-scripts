#!/bin/bash
##############################################################################
### @author      Patrick Feisthammel <patrick.feisthammel@citrin.ch> 
### @copyright   2014 Patrick Feisthammel
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Init
##############################################################################
pwd=$(dirname $0)

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "tvxh" OPTION; do
    case "$OPTION" in
        t) TEST=y; VERBOSE=$((VERBOSE + 1)) ;;
        v) VERBOSE=$((VERBOSE + 1)) ;;
        x) TRACE=y ;;
        h) usage; exit ;;
        ?) usage; exit 1 ;;
    esac
done

shift $((OPTIND-1))

read_config "$1"

##############################################################################
### Start
##############################################################################
test "$TRACE" && set -x

test "$TESLA_ID" || error_exit "Missing TESLA_ID)!"
test "$GUID" || error_exit "Missing Tesla Motors group channel GUID (GUID)!"
COOKIE_FILE=$pwd/cookies.txt
test -r "$COOKIE_FILE" || error_exit "Cookie-File not readable ($COOKIE_FILE). Use login.sh to create one."
APIURL=https://portal.vn.teslamotors.com/vehicles/$TESLA_ID/command/climate_state

##############################################################################
### Go
##############################################################################

. $pwd/tesla_go.sh

exit

##############################################################################
# USAGE >>

Fetch data Tesla API Server

Usage: $scriptname [options] config_file

Options:
    -t   Test mode, don't post
         Sets verbosity to info level
    -v   Set verbosity level to info level
    -vv  Set verbosity level to debug level
    -h   Show this help

See $pwd/tesla.conf.dist for details.

# << USAGE
