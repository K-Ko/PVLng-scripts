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
### Init
##############################################################################
. $pwd/../PVLng.sh

### Script options
opt_help      "Read data from Kaco inverters connected by RS485"
opt_help_hint "See dist/config.conf for details."

### PVLng default options with flag for save data
opt_define_pvlng x

. $(opt_build)

read_config "$CONFIG"

### Run only during daylight +- 60 min
check_daylight 60

check_lock $CONFIG

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_default TIMEOUT 1
check_default MAXATTEMPT 3

STTY_DEFAULT='406:0:8bd:8a30:3:1c:7f:8:4:2:64:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0'

##############################################################################
### Go
##############################################################################
# sudo chmod 666 /dev/ttyUSB0

for i in $(getGUIDs); do

    var_req INVERTER $i "Inverter number"
    var_req DEVICE $i Device

    sec 1 $i

    ### If not USE is set, set to $i
    var USE $i $i
    var GUID $USE

    var STTY $i "$STTY_DEFAULT"

    ### Prepare device
    stty -F $DEVICE $STTY

    QUERY="#$(printf '%02d' $INVERTER)0\r"

    lkv 2 QUERY $QUERY

    ### Up to MAXATTEMPT attempts to get valid data from DEVICE
    attempt=$MAXATTEMPT

    while :; do

        if [ $attempt -le 0 ]; then
            rc=9
            dataOut="$MAXATTEMPT times no data from $DEVICE"
            ### Exit while loop
            break
        fi

        lkv 2 'Attempts left' $attempt

        attempt=$((attempt - 1))

        ### Query inverter
        echo -en $QUERY > $DEVICE

        ### Get data from device
        data=

        while IFS= read -r -t $TIMEOUT -n 1 c; do
            ### Concatenate data
            data="$data$c"
        done < $DEVICE

        [ "$data" ] || continue

        lkv 2 'Data raw' "$data"

        ### Check & manipulate data
        dataOut=$(echo -n "$data" | \
        gawk -lordchr.so -v _adr=$INVERTER \
        '{
            ### Get data
            _data = $0;

            ### Split to array
            split(_data, _dataArray, "");

            ### Delete trailing CR
            if (ord(_dataArray[length (_dataArray)]) == 0x0d) {
                delete _dataArray[length(_dataArray)];
            }

            ### Check size
            switch (length(_dataArray)) {
                ### Type "00"/"02"
                case 64:
                    CRCposition = 57;
                    break;
                ### Type "000xi"
                case 63:
                    CRCposition = 57;
                    break;
                ### Type "XP(old)"
                case 78:
                    CRCposition = 61;
                    break;
                ### Not valid
                default:
                    printf("Invalid data size: %d", length (_dataArray));
                    exit 1;
            }

            ### Get CRC
            _CRC = ord(_dataArray[CRCposition]);

            ### Remove CRC
            delete _dataArray[CRCposition];

            ### Calc CRC
            _CRCcalculated = 0;
            for (i=1; i<CRCposition; i++) {
                _CRCcalculated += ord(_dataArray[i]);
            }
            _CRCcalculated %= 256;

            ### Check CRC
            if (_CRC != _CRCcalculated) {
                printf("Invalid crc: %d (data) %d (calculated)", _CRC, _CRCcalculated);
                exit 2;
            }

            ### Check "*" at position 1
            if (_dataArray[1] != "*") {
                printf ("invalid char: %s (%d) at position %d", _dataArray[1], ord(_dataArray[1]), 1);
                exit 4;
            }

            ### Check valid and right address 1..31 at position 2
            address = "";
            for (i=2; i<=3; i++) {
                if (_dataArray[i] ~ /[[:digit:]]/) {
                    address = address _dataArray[i];
                }
            }

            addressNum = strtonum(address);
            if (addressNum < 1 || addressNum > 31) {
                printf("Invalid address: %s (%d)", address, addressNum);
                exit 5;
            }

            if (addressNum != _adr) {
                printf("Wrong address: is %d, should %d", addressNum, _adr);
                exit 6;
            }

            ### Build _dataOut, join _dataArray back to string
            for (i in _dataArray) {
                _dataOut = _dataOut _dataArray[i];
            }

            ### Delete multiple spaces
            gsub(/[[:blank:]]+/, " ", _dataOut);

            ### Finally output manipulated data
            printf("%s", _dataOut);
        }')

        rc=$?

        ### No error occurred
        [ $rc -eq 0 ] && break

    done

    if [ $rc -eq 0 ]; then
        lkv 1 Data "$dataOut"
        ### Save data, extend response with actual timestamp
        PVLngPUT $GUID "$(date +'%F %H:%M:%S') $dataOut"
    else
        lkv 0 ERROR "[$rc] $dataOut"
    fi

done

