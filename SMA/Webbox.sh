#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2013 Knut Kohl
### @license     GNU General Public License http://www.gnu.org/licenses/gpl.txt
### @version     1.0.0
##############################################################################

##############################################################################
### Init variables
##############################################################################
pwd=$(dirname $0)
WEBBOX="192.168.0.168:80"

. $pwd/../PVLng.conf
. $pwd/../PVLng.sh

while getopts "stvxh" OPTION; do
    case "$OPTION" in
        s) SAVEDATA=y ;;
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

test "$WEBBOX" || error_exit "IP address is required!"

GUID_N=$(int "$GUID_N")
test $GUID_N -gt 0  || error_exit "No GUIDs defined (GUID_N)"

if test "$LOCATION"; then
    ### Location given, test for daylight time
    loc=$(echo $LOCATION | sed -e 's/,/\//g')
    daylight=$(PVLngGET "daylight/$loc/60.txt")
    log 2 "Daylight: $daylight"
    test $daylight -eq 1 || exit 127
fi

##############################################################################
### Go
##############################################################################
RESPONSEFILE=$(mktemp /tmp/pvlng.XXXXXX)

trap 'rm -f $TMPFILE $RESPONSEFILE >/dev/null 2>&1' 0

curl="$(curl_cmd)"

i=0

while test $i -lt $GUID_N; do

    i=$((i + 1))

    log 1 "--- $i ---"

    eval GUID=\$GUID_$i
    test "$GUID" || error_exit "Equipment GUID is required (GUID_$i)"

    ### request serial
    SERIAL=$(PVLngGET2 $GUID/serial.txt)
    test "$SERIAL" || error_exit "No serial number found for GUID: $GUID"

    ### Build RPC request, catch all channels from equipment
    cat >$TMPFILE <<EOT
{ "version": "1.0", "proc": "GetProcessData", "id": "$SERIAL", "format": "JSON",
  "params": { "devices": [ { "key": "$SERIAL", "channels": null } ] } }
EOT

    log 2 @$TMPFILE

    ### Query webbox
    $curl --output $RESPONSEFILE --data-urlencode RPC@$TMPFILE http://$WEBBOX/rpc
    rc=$?

    if test $rc -ne 0; then
        error_exit "cUrl error for Webbox: $rc"
    fi

    ### Test mode
    log 2 "Webbox response:"
    log 2 @$RESPONSEFILE

    ### Check response for error object
    if grep -q '"error"' $RESPONSEFILE; then
        error_exit "$(printf "ERROR from Webbox:\n%s" "$(cat $RESPONSEFILE)")"
    fi

    ### Save data
    test "$TEST" || PVLngPUT2 $GUID @$RESPONSEFILE

done

set +x

exit

##############################################################################
# USAGE >>

Read Inverter or Sensorbox data from SMA Webbox

Usage: $scriptname [options] config_file

Options:
    -s  Save data also into log file
    -t  Test mode, read only from Webbox and show the results, don't save to PVLng
        Sets verbosity to info level
    -v  Set verbosity level to info level
    -vv Set verbosity level to debug level
    -h  Show this help

See $pwd/Webbox.conf.dist for reference.

# << USAGE
