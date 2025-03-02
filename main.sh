#!/bin/bash
resize 2> /dev/null

export MENU_SIZE="$(($LINES - 8)) $(($COLUMNS - 16)) $(( $LINES - 16))"
export MSG_SIZE="8 54"



function create_database() {
    while true; do
        DB_NAME=$(whiptail --inputbox "Enter the name of the database to create" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            break
        elif [ -d "$DB_NAME" ]; then
            whiptail --msgbox "Database $DB_NAME already exists" $MSG_SIZE
        elif [ -z "$DB_NAME" ]; then
            whiptail --msgbox "Database name cannot be empty" $MSG_SIZE
        else
            mkdir "$DB_NAME"
            whiptail --msgbox "Database $(sed DB_NAME) created successfully" $MSG_SIZE
            break
        fi
    done
}

function list_databases() {
    DB_LIST=$(ls -d */ | sed 's/\///' | nl -w2 -s' ')
    DB_CHOICE=$(whiptail --title "Databases" --menu "Choose a database" $MENU_SIZE \
        $DB_LIST 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then 
        return
    else
        export DB_NAME=$(echo "$DB_LIST" | awk -v choice="$DB_CHOICE" '$1 == choice {print $2}')
        whiptail --msgbox "You selected database $DB_NAME" $MSG_SIZE
        ./database.sh
    fi
}

function main_menu() {
    while true; do
        OPTION=$(whiptail --title "Main Menu" --menu "Choose an option" $MENU_SIZE \
        "1" "Create Database" \
        "2" "List Databases" \
        "3" "Connect to Database" \
        "4" "Drop Database" \
        "5" "Exit" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            break
        fi

        case $OPTION in
            1)
                create_database
                ;;
            2)
                list_databases
                ;;
            3)
                # connect_to_database
                ;;
            4)
                # drop_database
                ;;
            5)
                break
                ;;
            *)
                whiptail --msgbox "Invalid option $OPTION" $MSG_SIZE
                ;;
        esac
    done
}

main_menu








