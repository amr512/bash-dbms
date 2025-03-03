#!/bin/bash

# populate variables $LINES and $COLUMNS
resize 2> /dev/null
MENU_SIZE="$(($LINES - 8)) $(($COLUMNS - 16)) $(( $LINES - 16))"
MSG_SIZE="8 54"
# replace string in file or string
function replace() {
    if [ ! -f "$3" ]; then
        echo $3 | sed "s/$1/$2/g"
    else
        sed -i "s/$1/$2/g" "$3"
    fi
}


# format options for whiptail
function prepare_options() {
    local i=0
    for e in $@; do
        echo $i $e
        i=$((i+1))
    done
}

