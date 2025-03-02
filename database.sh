#!/bin/bash

if [ ! -d "$DB_NAME" ]; then
    whiptail --msgbox "This script must be called from main.sh" $MSG_SIZE
    exit 1
fi
cd "$DB_NAME"

FIELD_TYPES=("1" "string" "2" "number" "3" "boolean")


function edit_table_fields(){

    FIELDS=$(head -n1 "$1.csv" | awk -F '-' '{print $1}' | sed s/,/\\n/g | nl -w2 -s' ')
    OPTION=$(whiptail --title "Fields" --menu "Choose an option" $MENU_SIZE \
        $FIELDS "+" "New Field" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        return
    fi
    if [ $OPTION == "+" ]; then
        FIELD_NAME=$(whiptail --inputbox "Enter the name of the field to add" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return
        fi
        FIELD_TYPE=$(whiptail --title "Field Type" --menu "Choose a field type" $MENU_SIZE \
            "${FIELD_TYPES[@]}" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return
        fi
        sed -i "s/-/,$FIELD_NAME:${FIELD_TYPES[$FIELD_TYPE]}-/" "$1.csv"
    fi
}


function create_table(){
    while true; do
        TABLE_NAME=$(whiptail --inputbox "Enter the name of the table to create" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            break
        elif [ -f "$TABLE_NAME.csv" ]; then
            whiptail --msgbox "Table $TABLE_NAME already exists" $MSG_SIZE
        elif [ -z "$TABLE_NAME" ]; then
            whiptail --msgbox "Table name cannot be empty" $MSG_SIZE
        else
            touch "$TABLE_NAME.csv"
            edit_table_fields "$TABLE_NAME"
            whiptail --msgbox "Table $TABLE_NAME created successfully" $MSG_SIZE
            break
        fi
    done
}

function list_tables(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            return
        else
            edit_table_fields "$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')"
        fi
    fi

}


function main_menu(){
    while true; do
        OPTION=$(whiptail --title "$DB_NAME" --menu "Choose an option" $MENU_SIZE \
        "1" "Create Table" \
        "2" "List Tables" \
        "3" "Insert Data" \
        "4" "Select Data" \
        "5" "Delete Data" \
        "6" "Update Data" \
        "7" "Drop Table" \
        "8" "Back to Main Menu" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            cd ..
            break
        fi

        case $OPTION in
            1)
                create_table
                ;;
            2)
                list_tables
                ;;
            3)
                # insert_data
                ;;
            4)
                # select_data
                ;;
            5)
                # delete_data
                ;;
            6)
                # update_data
                ;;
            7)
                # drop_table
                ;;
            8)
                cd ..
                break
                ;;
            *)
                whiptail --msgbox "Invalid option $OPTION" $MSG_SIZE
                ;;
        esac
    done

}

main_menu