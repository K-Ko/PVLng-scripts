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
opt_help      "Get last reading of a single channel.
Can be logged to file for e.g. for solar estimate over day"
opt_help_hint "See dist/watch.conf for details."

### PVLng default options
opt_define_pvlng

. $(opt_build)

read_config "$CONFIG"

##############################################################################
### Start
##############################################################################
[ "$TRACE" ] && set -x

check_required GUID "Channel GUID"
check_default FORMAT "%s"

##############################################################################
### Go
##############################################################################
set -- $(PVLngGET "data/$GUID.tsv?period=readlast")

### Got data?
[ "$1" ] || exit 0

### date time;timestamp
dt=$(date -d @$1 +'%Y-%m-%d %H:%M:%S;%s')

printf -v result "$dt;$FORMAT" "$2"

sec 1 Result
[ "$TEST" ] && log 1 "$result" || echo $result
