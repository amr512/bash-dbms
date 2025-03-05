#!/bin/bash
source utils.sh

if [ ! -d "$DB_NAME" ]; then
    whiptail --msgbox "This script must be called from main.sh" $MSG_SIZE
    exit 1
fi

cd "$DB_NAME"
FIELD_TYPES=("string" "number" "boolean")


function edit_field(){
    # change field type, make primary, or delete field
    local field_name=$(echo "$1" | awk -F '*' '{print $1}' | awk -F ':' '{print $1}')
    local field_type=$(echo "$1" | awk -F ':' '{print $2}' | awk -F '-' '{print $1}' | awk -F '*' '{print $1}')
    local is_primary=$(echo "$1" | grep "\*")
    local options=("Change_Type" "Make_Primary" "Delete_Field")
    local choice=$(whiptail --title "Edit Field" --menu "Choose an option" $MENU_SIZE $(prepare_options ${options[@]}) 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        return
    fi
    case $choice in
        0)
            local new_type=$(whiptail --title "Field Type" --menu "Choose a field type" $MENU_SIZE $(prepare_options ${FIELD_TYPES[@]}) 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then
                return
            fi
            sed -i "s/$field_name:$field_type/$field_name:${FIELD_TYPES[$new_type]}/" "$2.csv"
            ;;
        1)
            if [ -z "$is_primary" ]; then
                sed -i "s/\*//" "$2.csv"
                sed -i "s/$field_name:$field_type/$field_name:$field_type*/" "$2.csv"
                
            else
                whiptail --msgbox "Already a primary key" $MSG_SIZE
            fi
            ;;
        2)
            if [ -z "$is_primary" ]; then
                awk -v field="$field_name:$field_type" 'BEGIN{FS=OFS=","} 
                NR==1 {
                    for(i=1;i<=NF;i++) {
                        if($i==field) {
                            col=i
                            $i=""
                        }
                    }
                } 
                NR>1 {
                    for(i=1;i<=NF;i++) {
                        if(i==col) {
                            $i=""
                        }
                    }
                } 
                {
                    gsub(/,,/,",")
                    gsub(/,$/,"")
                    gsub(/^,/,"")
                }
                1' "$2.csv" > temp && mv temp "$2.csv"
            else
                whiptail --msgbox "You cannot delete the primary key of a table" $MSG_SIZE
            fi
            ;;
    esac

}

function manage_table_fields(){
    while true; do
        FIELDS=($(head -n1 "$1.csv" | tr ',' '\n'))
        OPTION=$(whiptail --title "Fields" --menu "Select a field to edit" $MENU_SIZE \
            $(prepare_options ${FIELDS[@]}) "+" "New Field" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            break
        fi
        if [ $OPTION == "+" ]; then
            FIELD_NAME=$(whiptail --inputbox "Enter the name of the field to add" $MSG_SIZE 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then
                return
            fi
            FIELD_TYPE=$(whiptail --title "Field Type" --menu "Choose a field type" $MENU_SIZE \
                $(prepare_options ${FIELD_TYPES[@]}) 3>&1 1>&2 2>&3) 
            if [ $? -ne 0 ]; then
                return
            fi
            if ! [ -z "$FIELD_NAME" ] && [[ $FIELD_NAME =~ ^[a-zA-Z0-9_]+$ ]]; then
                if [ -z "$FIELDS" ]; then
                    echo "$FIELD_NAME:${FIELD_TYPES[$FIELD_TYPE]}*" >> "$1.csv"
                else
                    export field="$FIELD_NAME:${FIELD_TYPES[$FIELD_TYPE]}"
                    awk 'BEGIN{FS=OFS=","} {if(NR==1){print $0","ENVIRON["field"]}else{print $0",-null-"}}' "$1.csv" > temp && mv temp "$1.csv"
                fi
            else 
                whiptail --msgbox "Name is empty or contains invalid characters" $MSG_SIZE
            fi
        else
            edit_field "${FIELDS[$OPTION]}" "$1"
            # whiptail --msgbox "You selected field ${FIELDS[$OPTION]}" $MSG_SIZE
            # sed -i "s/\*//" "$1.csv"
            # sed -i "s/${FIELDS[$OPTION]}/${FIELDS[$OPTION]}*/" "$1.csv"
        fi
    done
}



function create_table(){
    while true; do
        TABLE_NAME=$(whiptail --inputbox "Enter the name of the table to create" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            break
        elif [ -f "$TABLE_NAME.csv" ]; then
            whiptail --msgbox "Table $TABLE_NAME already exists" $MSG_SIZE
        elif [ -z "$TABLE_NAME" ] || ![[ $TABLE_NAME =~ ^[a-zA-Z0-9_]+$ ]]; then
            whiptail --msgbox "Table name cannot be empty or contain invalid characters" $MSG_SIZE
        else
            touch "$TABLE_NAME.csv"
            manage_table_fields "$TABLE_NAME"
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
            manage_table_fields "$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')"
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