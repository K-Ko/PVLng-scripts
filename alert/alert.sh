#!/bin/bash
##############################################################################
### @author      Knut Kohl <github@knutkohl.de>
### @copyright   2012-2015 Knut Kohl
### @license     MIT License (MIT) http://opensource.org/licenses/MIT
### @version     1.0.0
##############################################################################

##############################################################################
### Constants
##############################################################################
pwd=$(dirname $0)

##############################################################################
### Functions
##############################################################################
function replace_vars {
    ### Prepare conditions
    local str="$1" ### save for looping
    local count=$2
    local i=0
    local value=
    local name=
    local last=

    ### On replacing in Condition, $EMPTY is not set, so it works on real data

    ### max. 10 parameters :-)
    while [ $i -lt $count ]; do
        i=$((i+1))

        var1 name $i
        var1 last $i
        var1 value $i
        [ -z "$value" ] && value=$EMPTY

        str=$(echo "$str" | sed "s~[{]VALUE_$i[}]~$value~g;s~[{]NAME_$i[}]~$name~g;s~[{]LAST_$i[}]~$last~g")
    done

    ### VALUE, NAME and LAST stands also for *_1
    [ -z "$value_1" ] && value_1=$EMPTY
    echo "$str" | sed "s~[{]VALUE[}]~$value_1~g;s~[{]NAME[}]~$name_1~g;s~[{]LAST[}]~$last_1~g"
}

### --------------------------------------------------------------------------
function alert_log {
    lkv 1 "PVLng log" "$GUID - $value"

    [ "$TEST" ] && return
    save_log 'Alert' "{NAME}: {VALUE}"
}

### --------------------------------------------------------------------------
function alert_logger {
    var1 MESSAGE $i
    MESSAGE=$(replace_vars "${MESSAGE:-{NAME\}: {VALUE\}}" $j)
    lkv 1 Logger "$MESSAGE"

    [ "$TEST" ] && return
    logger -t PVLng "$MESSAGE"
}

### --------------------------------------------------------------------------
function alert_mail {
    var1 EMAIL $i
    [ "$EMAIL" ] || error_exit "Email is required! (ACTION_${i}_${j}_EMAIL)"

    var1 SUBJECT $i
    SUBJECT=$(replace_vars "${SUBJECT:-[PVLng] {NAME\}: {VALUE\}}" $j)

    var1 BODY $i
    BODY=$(replace_vars "$BODY" $j)

    lkv 1 "Send email" "$EMAIL"
    lkv 1 Subject "$SUBJECT"
    sec 1 Body "$BODY"

    [ "$TEST" ] && return
    echo -e "$BODY" | mail -s "$SUBJECT" $EMAIL >/dev/null
}

### --------------------------------------------------------------------------
function alert_file {
    var1 DIR $i
    [ "$DIR" ] || exit_required Directory DIR_${i}

    var1 PREFIX $i

    var1 TEXT $i
    TEXT=$(replace_vars "${TEXT:-{NAME\}: {VALUE\}}" $j)
    lkv 1 TEXT "$TEXT"

    [ "$TEST" ] && return
    echo -n "$TEXT" >$(mktemp --tmpdir="$DIR" ${PREFIX:-alert}.XXXXXX)
}

### --------------------------------------------------------------------------
function alert_twitter {
    ### Like "file" but with defined file name pattern for twitter-alert.sh
    var1 TEXT $i
    TEXT=$(replace_vars "${TEXT:-{NAME\}: {VALUE\}}" $j)
    lkv 1 TEXT "$TEXT"

    [ "$TEST" ] && return
    echo -n "$TEXT" >$(mktemp --tmpdir="$RUNDIR" twitter.alert.XXXXXX)
}

##############################################################################
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Alert on channels conditions"
opt_help_hint "See dist/alert.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

GUID_N=$(int "$GUID_N")
[ $GUID_N -gt 0 ] || exit_required Sections GUID_N

##############################################################################
### Go
##############################################################################
i=0

while [ $i -lt $GUID_N ]; do

    i=$((i+1))

    sec 1 $i

    EMPTY=

    var1 USE $i

    if [ "$USE" ]; then var1 GUID $USE; else var1 GUID $i; fi

    j=0

    ### Split comma separated GUIDs
    for GUID in $(echo "$GUID" | sed 's/ *, */ /g'); do

        ### Count GUIDs for function replace_vars
        j=$((j+1))

        if [ "$USE" ]; then
            eval name="\$name_$USE"
            eval value="\$value_$USE"
            eval last="\$last_$USE"
        else
            PVLngChannelAttr $GUID name
            PVLngChannelAttr $GUID description
            [ "$description" ] && name="$name ($description)"

            set -- $(PVLngGET data/$GUID.tsv?period=readlast)
            shift ### Shift out timestamp
            value=$@

            lkv 2 "$name" "$value"

            lastkey=$(key_name alert $CONFIG $i.$j.last)
            last=$(PVLngStoreGET $lastkey)
            [ "$TEST" -o "$last" == "$value" ] || PVLngStorePUT $lastkey "$value"
        fi

        eval name_$j="\$name"
        eval value_$j="\$value"
        eval last_$j="\$last"
    done

    oncekey=$(key_name alert $CONFIG $i.once)

    ### Prepare condition
    var1 CONDITION $i
    [ "$CONDITION" ] || exit_required Condition CONDITION_$i
    CONDITION=$(echo "$CONDITION" | sed 's~'\''~\\'\''~g')

    CONDITION=$(replace_vars "$CONDITION" $j)
    lkv 1 Condition "$CONDITION"

    result=$(calc "$CONDITION" 0)

    ### Skip if condition is not true
    if [ $result -eq 0 ]; then
        log 1 "Skip, condition not apply."
        ### Remove flag
        [ "$TEST" ] || PVLngStorePUT $oncekey
        continue
    fi

    ### Condition was true
    var1bool ONCE $i

    ### Skip if flag file exists, condition was true before && ONCE is set
    if [ $ONCE -eq 1 -a "$(PVLngStoreGET $oncekey)" ]; then
        log 1 "Skip, report condition '$CONDITION' only once"
        continue
    fi

    if [ $ONCE -eq 1 ]; then
        ### Mark condition was true
        [ "$TEST" ] || PVLngStorePUT $oncekey x
    else
        ### Remove flag
        [ "$TEST" ] || PVLngStorePUT $oncekey
    fi

    var1 ACTION $i
    : ${ACTION:=log}

    var1 EMPTY $i
    : ${EMPTY:=<empty>}

    ### Check if action function exists
    eval f=$(declare -F alert_$ACTION)
    if [ "$f" ]; then
        eval alert_$ACTION
    else
        log 0 ERROR - Unknown function: $ACTION
    fi

done

