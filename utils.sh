#!/bin/bash

# populate variables $LINES and $COLUMNS
resize 2> /dev/null
MENU_SIZE="$(($LINES - 8)) $(($COLUMNS - 16)) $(( $LINES - 16))"
TEXTBOX_SIZE="$(($LINES - 4)) $(($COLUMNS - 8))"
MSG_SIZE="8 54"



# format options for whiptail
function prepare_options() {
    local i=0
    for e in $@; do
        echo $i $e
        i=$((i+1))
    done
}

