#!/bin/bash

source utils.sh





function create_database() {
    while true; do
        DB_NAME=$(whiptail --inputbox "Enter the name of the database to create" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            break
        elif [ -d "$DB_NAME" ]; then
            whiptail --msgbox "Database $DB_NAME already exists" $MSG_SIZE
        elif [ -z "$DB_NAME" ] || ! [[ $DB_NAME =~ ^[a-zA-Z0-9_]+$ ]]; then
            whiptail --msgbox "Name is empty or contains invalid characters" $MSG_SIZE
        else
            mkdir "$DB_NAME"
            whiptail --msgbox "Database $DB_NAME created successfully" $MSG_SIZE
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

function connect_to_database() {
    list_databases
}

function drop_database() {
    DB_LIST=$(ls -d */ | sed 's/\///' | nl -w2 -s' ')
    DB_CHOICE=$(whiptail --title "Databases" --menu "Choose a database to drop" $MENU_SIZE \
        $DB_LIST 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then 
        return
    else
        CONFIRM=$(whiptail --title "Drop Database" --yesno "Are you sure you want to drop database $(echo "$DB_LIST" | awk -v choice="$DB_CHOICE" '$1 == choice {print $2}')?" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then
            rm -r $(echo "$DB_LIST" | awk -v choice="$DB_CHOICE" '$1 == choice {print $2}')
            whiptail --msgbox "Database $(echo "$DB_LIST" | awk -v choice="$DB_CHOICE" '$1 == choice {print $2}') dropped successfully" $MSG_SIZE
        fi
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
                connect_to_database
                ;;
            4)
                drop_database
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








