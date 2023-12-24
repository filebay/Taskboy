#!/bin/bash

# File to store tasks
TODO_FILE="$HOME/taskboy/.taskboy.csv"
LOCK_FILE="$HOME/taskboy/.taskboy.lock"
HASH_FILE="$HOME/taskboy/.taskboy.hash"
STANDALONE_FILE="$HOME/taskboy/.taskboy.standalone"

# Initialize the system on the first run
if [ ! -f "$TODO_FILE" ]; then
    touch "$TODO_FILE"
    echo "id,task,due_date,priority,category,status" | base64 > "$TODO_FILE"
fi

if [ ! -f "$LOCK_FILE" ]; then
    touch "$LOCK_FILE"
fi

if [ ! -f "$HASH_FILE" ]; then
    echo "Please set a new password for taskboy:"
    read -s new_password
    echo -n "$new_password" | shasum -a 256 | cut -d' ' -f1 > "$HASH_FILE"
fi

# Display usage information
usage() {
    echo "Usage:"
    if [ ! -f "$STANDALONE_FILE" ]; then
        echo "  taskboy standalone - Use taskboy in standalone mode."
    fi
    echo "  taskboy settings - Access additional options."
    if [ -f "$STANDALONE_FILE" ] || [ ! -f "$LOCK_FILE" ]; then
        echo "  taskboy add - Add a new task interactively."
        echo "  taskboy list - List all tasks."
        echo "  taskboy done TASK_ID - Mark a task as done."
        echo "  taskboy delete TASK_ID - Delete a task."
    fi
    if [ ! -f "$STANDALONE_FILE" ]; then
        echo "  taskboy lock - Lock the task list from editing."
    fi
}

# Settings menu
settings_menu() {
    echo "Settings:"
    if [ ! -f "$STANDALONE_FILE" ]; then
        echo "  1. Use taskboy in standalone mode."
    fi
    echo "  2. Install taskboy"
    echo "  3. Uninstall taskboy"
    echo "  4. Reset configuration"
    echo "  5. Wipe CSV and start from scratch"
    echo "  6. Back to main menu"
    read -p "Select an option: " setting_choice

    case $setting_choice in
        1)
            rm -f "$LOCK_FILE"
            touch "$STANDALONE_FILE"
            echo "Standalone mode activated."
            ;;
        2)
            install_taskboy
            ;;
        3)
            uninstall_taskboy
            ;;
        4)
            reset_configuration
            ;;
        5)
            wipe_csv
            ;;
        6)
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
}

# Installation function
install_taskboy() {
    local script_path=$(realpath "$0")
    echo "Select your shell:"
    echo "1. Bash"
    echo "2. Zsh"
    echo "3. Fish"
    echo "4. Other"
    read -p "Enter your choice (1/2/3/4): " shell_choice

    case $shell_choice in
        1)
            echo "alias taskboy='$script_path'" >> "$HOME/.bashrc"
            echo "Taskboy installed for Bash. Please restart your terminal."
            ;;
        2)
            echo "alias taskboy='$script_path'" >> "$HOME/.zshrc"
            echo "Taskboy installed for Zsh. Please restart your terminal."
            ;;
        3)
            echo "alias taskboy='$script_path'" >> "$HOME/.config/fish/config.fish"
            echo "Taskboy installed for Fish. Please restart your terminal."
            ;;
        4)
            read -p "Enter the full path of your shell profile file: " profile_file
            if [ -f "$profile_file" ]; then
                echo "alias taskboy='$script_path'" >> "$profile_file"
                echo "Taskboy installed. Please restart your terminal or source your profile file."
            else
                echo "Profile file not found. Installation aborted."
            fi
            ;;
        *)
            echo "Invalid choice. Installation aborted."
            ;;
    esac
}

# Uninstallation function
uninstall_taskboy() {
    local script_path=$(realpath "$0")
    local alias_line="alias taskboy='$script_path'"

    for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
        if [ -f "$profile" ]; then
            grep -vF "$alias_line" "$profile" > "$profile.tmp" && mv "$profile.tmp" "$profile"
        fi
    done

    echo "Taskboy alias removed. Please restart your terminal or source your profile file."
}

# Reset configuration
reset_configuration() {
    rm -f "$HASH_FILE"
    echo "Please set a new password for taskboy:"
    read -s new_password
    echo -n "$new_password" | shasum -a 256 | cut -d' ' -f1 > "$HASH_FILE"
    echo "Configuration reset. Please restart taskboy."
    exit 0
}

# Wipe CSV and start from scratch
wipe_csv() {
    rm -f "$TODO_FILE"
    touch "$TODO_FILE"
    echo "id,task,due_date,priority,category,status" | base64 > "$TODO_FILE"
    echo "CSV file wiped and reset."
}

# Add a task
add_task() {
    echo -n "Enter task description: "
    read task
    echo -n "Enter due date (YYYY-MM-DD): "
    read due_date
    echo -n "Enter priority (Low, Medium, High): "
    read priority
    echo -n "Enter category: "
    read category

    local last_id=$(tail -n 1 "$TODO_FILE" | grep -v 'id,task' | cut -d, -f1)
    local new_id=$((last_id + 1))

    if [ -z "$last_id" ]; then
        new_id=1
    fi

    echo "$new_id,$task,$due_date,$priority,$category,Pending" | base64 >> "$TODO_FILE"
    echo "Task added with ID $new_id"
}

# List all tasks
list_tasks() {
    echo "Current Tasks:"
    echo "ID | Description | Due Date | Priority | Category | Status"
    cat "$TODO_FILE" | base64 --decode | awk -F, 'BEGIN{OFS=" | "} NR>1 {print $1,$2,$3,$4,$5,$6}' | column -t -s'|'
}

# Mark a task as done
mark_as_done() {
    local task_id=$1
    if [ -z "$task_id" ]; then
        echo "Error: No task ID provided for marking as done."
        exit 1
    fi

    if ! grep -q "^$task_id," "$TODO_FILE" | base64 --decode; then
        echo "Error: Task ID $task_id does not exist."
        exit 1
    fi

    local temp_file=$(mktemp)
    cat "$TODO_FILE" | base64 --decode | awk -F, -v task_id="$task_id" 'BEGIN{OFS=","} {if ($1 == task_id) $6="Done"; print}' > "$temp_file"
    if [ -s "$temp_file" ]; then
        cat "$temp_file" | base64 > "$TODO_FILE"
        echo "Task $task_id marked as done."
    else
        echo "Error: Task ID $task_id does not exist."
    fi
}

# Delete a task
delete_task() {
    local task_id=$1
    if [ -z "$task_id" ]; then
        echo "Error: No task ID provided for deletion."
        exit 1
    fi

    if ! grep -q "^$task_id," "$TODO_FILE" | base64 --decode; then
        echo "Error: Task ID $task_id does not exist."
        exit 1
    fi

    local temp_file=$(mktemp)
    cat "$TODO_FILE" | base64 --decode | awk -F, -v task_id="$task_id" 'BEGIN{OFS=","} {if ($1 != task_id) print}' > "$temp_file"
    if [ -s "$temp_file" ]; then
        cat "$temp_file" | base64 > "$TODO_FILE"
        echo "Task $task_id deleted."
    else
        echo "Error: Task ID $task_id does not exist."
    fi
}

# Lock the task list
lock_tasklist() {
    touch "$LOCK_FILE"
    echo "Task list locked."
}

# Unlock the task list
unlock_tasklist() {
    echo "Enter password to unlock:"
    read -s password
    password_hash=$(echo -n "$password" | shasum -a 256 | cut -d' ' -f1)

    if [[ "$password_hash" == "$(cat $HASH_FILE)" ]]; then
        rm -f "$LOCK_FILE"
        echo "Task list unlocked."
    else
        echo "Incorrect password."
    fi
}

# Handling command line arguments
subcommand=$1; shift

if [ -f "$STANDALONE_FILE" ] || [ ! -f "$LOCK_FILE" ]; then
    case "$subcommand" in
        add)
            add_task
            ;;
        list)
            list_tasks
            ;;
        done)
            mark_as_done "$1"
            ;;
        delete)
            delete_task "$1"
            ;;
        settings)
            settings_menu
            ;;
        *)
            usage
            ;;
    esac
else
    case "$subcommand" in
        standalone)
            rm -f "$LOCK_FILE"
            touch "$STANDALONE_FILE"
            echo "Standalone mode activated."
            ;;
        settings)
            settings_menu
            ;;
        lock)
            lock_tasklist
            ;;
        unlock)
            unlock_tasklist
            ;;
        *)
            usage
            ;;
    esac
fi
