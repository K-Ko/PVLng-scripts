#!/bin/bash
##############################################################################
### @author      Patrick Feisthammel <patrick.feisthammel@citrin.ch> 
### @copyright   2014 Patrick Feisthammel
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Go
##############################################################################
RESPONSEFILE=$(mktemp /tmp/pvlng.XXXXXX)
TMPFILE=$(mktemp /tmp/pvlng.XXXXXX)

trap 'rm -f $TMPFILE $RESPONSEFILE >/dev/null 2>&1' 0

log 2 "$APIURL"

curl="$(curl_cmd) -b $COOKIE_FILE"

### Query Tesla-Server
$curl --output $RESPONSEFILE $APIURL
rc=$?

log 2 @$RESPONSEFILE

if test $rc -ne 0; then
     error_exit "cUrl error for Tesla API: $rc"
fi

### Remove null values, they mean: no information
perl -pe 's/,"[a-z0-9_]+":null//g' <$RESPONSEFILE >$TMPFILE 
mv $TMPFILE $RESPONSEFILE

### Test mode
log 2 "Tesla Server response:"
log 2 @$RESPONSEFILE

test "$TEST" || PVLngPUT $GUID @$RESPONSEFILE

