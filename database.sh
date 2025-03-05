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


function insert_data(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            return
        else
            TABLE_NAME=$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')
            FIELDS=($(head -n1 "$TABLE_NAME.csv" | tr ',' '\n'))
            if [ -z "$FIELDS" ]; then
                whiptail --msgbox "No fields found in table $TABLE_NAME" $MSG_SIZE
                return
            fi
            DATA=""
            for field in "${FIELDS[@]}"; do
                field_name=$(echo "$field" | awk -F ':' '{print $1}')
                field_type=$(echo "$field" | awk -F ':' '{print $2}' | awk -F '-' '{print $1}' | awk -F '*' '{print $1}')
                is_primary=$(echo "$field" | grep "\*")
                while true; do
                    if [ "$field_type" == "boolean" ]; then
                        value=$(whiptail --title "Enter value for $field_name ($field_type)" --menu "Choose a value for $field_name ($field_type)" $MENU_SIZE \
                            "true" "" \
                            "false" "" 3>&1 1>&2 2>&3)
                    else
                        value=$(whiptail --inputbox "Enter value for $field_name ($field_type)" $MSG_SIZE 3>&1 1>&2 2>&3)
                    fi
                    if [ $? -ne 0 ]; then
                        return
                    fi
                    if [ ! -z "$is_primary" ]; then
                        export val=$value
                        awk -F, '{if(NR>1){for(i=1;i<=NF;i++){if(ENVIRON["val"]==$i){exit 1}}}}' "$TABLE_NAME.csv"
                        if [ $? -eq 1 ]; then
                            whiptail --msgbox "Primary key value already exists" $MSG_SIZE
                            continue
                        fi
                    fi
                    if [ -z "$value" ]; then
                        if [ ! -z "$is_primary" ]; then
                            whiptail --msgbox "Primary key cannot be empty" $MSG_SIZE
                            continue
                        else
                            value="-null-"
                        fi
                    fi
                    if [ "$field_type" == "number" ] && ! [[ "$value" =~ ^[0-9]+$ ]]; then
                        whiptail --msgbox "Value must be a number" $MSG_SIZE
                    elif [ "$field_type" == "boolean" ] && ! [[ "$value" =~ ^(true|false)$ ]]; then
                        whiptail --msgbox "Value must be true or false" $MSG_SIZE
                    else

                        DATA="$DATA,$value"
                        break
                    fi
                done
            done
            echo "${DATA:1}" >> "$TABLE_NAME.csv"
            whiptail --msgbox "Data inserted successfully" $MSG_SIZE
        fi
    fi
}

function select_data(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            whiptail --msgbox "No table selected" $MSG_SIZE
            return
        else
            TABLE_NAME=$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')
            # pick from [select all, select by value on string, number, or boolean field, select by range on number field]
            OPTIONS=("Select_All" "Select_by_Value" "Select_by_Range")
            SELECT_OPTION=$(whiptail --title "Select Data" --menu "Choose an option" $MENU_SIZE $(prepare_options ${OPTIONS[@]}) 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then
                return
            fi
            case $SELECT_OPTION in
                0)
                    column -s, -t -o" | "< "$TABLE_NAME.csv" > temp_table.tmp
                    whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                    rm temp_table.tmp
                    ;;
                1)
                    select_by_value "$TABLE_NAME" | column -s, -t -o" | "> temp_table.tmp
                    whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                    rm temp_table.tmp
                    ;;
                2)
                    select_by_range "$TABLE_NAME" | column -s, -t -o" | "> temp_table.tmp
                    whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                    rm temp_table.tmp
                    ;;
            esac
        fi
    fi
}

function select_by_value(){
    local TABLE_NAME=$1
    FIELDS=($(head -n1 "$TABLE_NAME.csv" | tr ',' '\n'))
    FIELD_CHOICE=$(whiptail --title "Fields" --menu "Choose a field to select by" $MENU_SIZE $(prepare_options ${FIELDS[@]}) 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        return
    fi
    FIELD_NAME=$(echo "${FIELDS[$FIELD_CHOICE]}" | awk -F ':' '{print $1}')
    FIELD_TYPE=$(echo "${FIELDS[$FIELD_CHOICE]}" | awk -F ':' '{print $2}' | awk -F '-' '{print $1}' | awk -F '*' '{print $1}')
    if [ "$FIELD_TYPE" == "boolean" ]; then
        VALUE=$(whiptail --title "Enter value for $FIELD_NAME ($FIELD_TYPE)" --menu "Choose a value for $FIELD_NAME ($FIELD_TYPE)" $MENU_SIZE \
            "true" "" \
            "false" "" 3>&1 1>&2 2>&3)
    else
        VALUE=$(whiptail --inputbox "Enter value for $FIELD_NAME ($FIELD_TYPE)" $MSG_SIZE 3>&1 1>&2 2>&3)
    fi
    if [ $? -ne 0 ]; then
        return
    fi
    if [ -z "$VALUE" ]; then
        whiptail --msgbox "Value cannot be empty" $MSG_SIZE
        return
    fi
    export field="${FIELDS[$FIELD_CHOICE]}"
    export value="$VALUE"
    echo "$field,$value" > choices.tmp
    awk 'BEGIN{FS=OFS=","} NR==1{for(i=1;i<=NF;i++){if($i==ENVIRON["field"]){col=i}}print} NR>1{if($col==ENVIRON["value"])print}' "$TABLE_NAME.csv" 
}

function select_by_range(){
    local TABLE_NAME=$1
    while true; do
        FIELDS=($(head -n1 "$TABLE_NAME.csv" | tr ',' '\n'))
        FIELD_CHOICE=$(whiptail --title "Fields" --menu "Choose a field to select by" $MENU_SIZE $(prepare_options ${FIELDS[@]}) 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return
        fi
        FIELD_TYPE=$(echo "${FIELDS[$FIELD_CHOICE]}" | awk -F ':' '{print $2}' | awk -F '*' '{print $1}')
        if  ! [ "$FIELD_TYPE" == "number" ]; then
            whiptail --msgbox "Field must be a number" $MSG_SIZE
            continue
        fi
        break
    done
    while true; do
        MIN=$(whiptail --inputbox "Enter minimum value for $FIELD_NAME" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return
        fi
        MAX=$(whiptail --inputbox "Enter maximum value for $FIELD_NAME" $MSG_SIZE 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return
        fi
        if [ -z "$MIN" ] || [ -z "$MAX" ]; then
            whiptail --msgbox "Value cannot be empty" $MSG_SIZE
            continue
        elif ! [[ "$MIN" =~ ^[0-9]+$ ]] || ! [[ "$MAX" =~ ^[0-9]+$ ]]; then
            whiptail --msgbox "Value must be a number" $MSG_SIZE
            continue
        else 
            break
        fi
    done
    export min="$MIN"
    export max="$MAX"
    export field="${FIELDS[$FIELD_CHOICE]}"
    awk 'BEGIN{FS=OFS=","} NR==1{for(i=1;i<=NF;i++){if($i==ENVIRON["field"]){col=i}}print} NR>1{if($col != "-null-" && ($col)+0>=ENVIRON["min"]+0 && ($col)+0<=ENVIRON["max"]+0){print}}' "$TABLE_NAME.csv"
}

function delete_data(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            return
        else
            TABLE_NAME=$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')
            OPTIONS=("Delete_by_Value" "Delete_by_Range")
            DELETE_OPTION=$(whiptail --title "Delete Data" --menu "Choose an option" $MENU_SIZE $(prepare_options ${OPTIONS[@]}) 3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then
                return
            fi
            case $DELETE_OPTION in
                0)
                    select_by_value "$TABLE_NAME" | tail -n +2 > temp_table.tmp
                    if [ -s temp_table.tmp ]; then
                        whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                        whiptail --title "Confirm Delete" --yesno "Are you sure you want to delete the selected data?" $MSG_SIZE
                        if [ $? -eq 0 ]; then
                            awk 'BEGIN{FS=OFS=","} NR==FNR{lines[$0]; next} !($0 in lines)' temp_table.tmp "$TABLE_NAME.csv" > temp && mv temp "$TABLE_NAME.csv"
                            whiptail --msgbox "Data deleted successfully" $MSG_SIZE
                            rm temp_table.tmp
                        fi
                    else
                        whiptail --msgbox "No matching data found" $MSG_SIZE
                    fi
                    rm temp_table.tmp
                    ;;
                1)
                    select_by_range "$TABLE_NAME" | tail -n +2 > temp_table.tmp
                    if [ -s temp_table.tmp ]; then
                        whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                        whiptail --title "Confirm Delete" --yesno "Are you sure you want to delete the selected data?" $MSG_SIZE
                        if [ $? -eq 0 ]; then
                            awk 'BEGIN{FS=OFS=","} NR==FNR{lines[$0]; next} !($0 in lines)' temp_table.tmp "$TABLE_NAME.csv" > temp && mv temp "$TABLE_NAME.csv"
                            whiptail --msgbox "Data deleted successfully" $MSG_SIZE
                            rm temp_table.tmp
                        fi

                    else
                        whiptail --msgbox "No matching data found" $MSG_SIZE
                    fi
                    rm temp_table.tmp
                    ;;
            esac
        fi
    fi
}

function update_data(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            return
        else
            TABLE_NAME=$(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')
            # FIELDS=($(head -n1 "$TABLE_NAME.csv" | tr ',' '\n'))
            # FIELD_CHOICE=$(whiptail --title "Fields" --menu "Choose a field to select by" $MENU_SIZE $(prepare_options ${FIELDS[@]}) 3>&1 1>&2 2>&3)
            # SEARCH_VALUE=$(whiptail --inputbox "Enter value to select by" $MSG_SIZE 3>&1 1>&2 2>&3)
            # if [ $? -ne 0 ]; then
            #     return
            # fi
            rm choices.tmp
            select_by_value "$TABLE_NAME" | tail -n +2 > temp_table.tmp
            if [ -s temp_table.tmp ]; then
                whiptail --scrolltext --textbox temp_table.tmp $TEXTBOX_SIZE
                FIELDS=($(head -n1 "$TABLE_NAME.csv" | tr ',' '\n'))
                FIELD_CHOICE=$(whiptail --title "Fields" --menu "Choose a field to update" $MENU_SIZE $(prepare_options ${FIELDS[@]}) 3>&1 1>&2 2>&3)
                if [ $? -ne 0 ]; then
                    return
                fi
                FIELD_NAME=$(echo "${FIELDS[$FIELD_CHOICE]}" | awk -F ':' '{print $1}')
                FIELD_TYPE=$(echo "${FIELDS[$FIELD_CHOICE]}" | awk -F ':' '{print $2}' | awk -F '-' '{print $1}' | awk -F '*' '{print $1}')
                if [ "$FIELD_TYPE" == "boolean" ]; then
                    NEW_VALUE=$(whiptail --title "Enter new value for $FIELD_NAME ($FIELD_TYPE)" --menu "Choose a value for $FIELD_NAME ($FIELD_TYPE)" $MENU_SIZE \
                        "true" "" \
                        "false" "" 3>&1 1>&2 2>&3)
                else
                    NEW_VALUE=$(whiptail --inputbox "Enter new value for $FIELD_NAME ($FIELD_TYPE)" $MSG_SIZE 3>&1 1>&2 2>&3)
                fi
                if [ $? -ne 0 ]; then
                    return
                fi
                if [ -z "$NEW_VALUE" ]; then
                    whiptail --msgbox "Value cannot be empty" $MSG_SIZE
                    return
                fi
                export field="${FIELDS[$FIELD_CHOICE]}"
                export new_value="$NEW_VALUE"
                export select="$(cut -d, -f1 choices.tmp)"
                export value="$(cut -d, -f2 choices.tmp)"
                # echo $value $new_value $field $select
                awk 'BEGIN{FS=OFS=","}
                NR==1{
                for(i=1;i<=NF;i++){
                if($i==ENVIRON["field"])
                {col=i}
                if($i==ENVIRON["select"])
                {select_col=i}
                }
                 print}
                NR>1{
                if($select_col==ENVIRON["value"])
                {$col=ENVIRON["new_value"]}
                print $0}' "$TABLE_NAME.csv" > temp && mv temp "$TABLE_NAME.csv"
                whiptail --msgbox "Data updated successfully" $MSG_SIZE
                rm temp_table.tmp
            else
                whiptail --msgbox "No matching data found" $MSG_SIZE
                rm temp_table.tmp
            fi
        fi
    fi
}

function drop_table(){
    TABLES=$(ls *.csv | sed 's/.csv//' | nl -w2 -s' ')
    if [ -z "$TABLES" ]; then
        whiptail --msgbox "No tables found" $MSG_SIZE
    else
        OPTION=$(whiptail --title "Tables" --menu "Choose a table to drop" $MENU_SIZE \
        $TABLES 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            return
        else
            CONFIRM=$(whiptail --title "Drop Table" --yesno "Are you sure you want to drop table $(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}')?" $MSG_SIZE 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                rm $(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}').csv
                whiptail --msgbox "Table $(echo "$TABLES" | awk -v choice="$OPTION" '$1 == choice {print $2}') dropped successfully" $MSG_SIZE
            fi
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
                insert_data
                ;;
            4)
                select_data
                ;;
            5)
                delete_data
                ;;
            6)
                update_data
                ;;
            7)
                drop_table
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