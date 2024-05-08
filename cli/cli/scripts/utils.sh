#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
SHARED="$DEPLOYMENT_DIR/shared"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
BACKGROUND_PIDS="$SHARED/background.pids"
if [[ $DEPLOYMENT_DIR != "" ]]; then
    mkdir -p "$SHARED"
fi

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
BOLD_WHITE='\033[1;37m'
# shellcheck disable=SC2034
BOLD_WHITE_ON_RED='\033[1;37;41m'
# shellcheck disable=SC2034
BOLD_WHITE_ON_ORANGE='\033[1;37;48;5;208m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
BOLD_WHITE_ON_GREEN='\033[1;37;42m'
# shellcheck disable=SC2034
YELLOW='\033[0;33m'
# shellcheck disable=SC2034
NC='\033[0m' # No Color
# shellcheck disable=SC2034
CLEARUP='\033[K'

# Declare global variables
animation_pid=""
latest_elapsed_time=""
start_time=""

cleanup() {
    # This function is called when the script is interrupted (e.g., Ctrl+C).
    if [ -n "$animation_pid" ]; then
        kill "$animation_pid"  # Terminate the loading animation
    fi

    if [ -f "$BACKGROUND_PIDS" ]; then
        # Read pids from background.pids and kill each process
        while IFS= read -r pid; do
            # If the process exists, kill it
            if kill -0 "$pid" >/dev/null 2>&1; then
                kill "$pid"
            fi
        done < "$BACKGROUND_PIDS"

        # Remove the PID log file
        rm "$BACKGROUND_PIDS"
    fi
    exit 1
}

# Set up the trap to call the cleanup function on Ctrl+C
trap cleanup INT

show_loading_animation() {
    start_time=$(date +%s)
    latest_elapsed_time="00:00:00"

    local func_name="$2"
    local indentation_level="${3:-1}"
    local sleep_duration="0.5"
    local spinner="/-\\|"
    local spinner_length=${#spinner}
    local spinner_index=0

    local indentation=""
    for ((i=1; i<=indentation_level; i++)); do
        indentation+="\t"
    done

    # Determine the character based on the indentation level
    local prefix=''
    if [ $((indentation_level % 2)) -eq 1 ]; then
        prefix='-'
    else
        prefix='*'
    fi

    echo -n -e "$indentation$prefix [00:00:00] $1 ${spinner:0:1}"

    while true; do
        elapsed_time=$(($(date +%s) - start_time))
        echo "$elapsed_time" > "$SHARED/$func_name.elapsed"

        if [[ $(uname) == "Darwin" ]]; then
            formatted_elapsed_time=$(date -u -r ${elapsed_time} +"%T")
        else
            formatted_elapsed_time=$(date -u -d @${elapsed_time} +"%T")
        fi
        latest_elapsed_time="$formatted_elapsed_time"
        spinner_char="${spinner:${spinner_index}:1}"

        echo -n -e "\r$indentation$prefix [$latest_elapsed_time] $1 $spinner_char"

        spinner_index=$(( (spinner_index + 1) % spinner_length ))

        sleep $sleep_duration
    done
}

command_exists() {
    type "$1" &> /dev/null
}

do_nothing() {
    sleep 1
    errors=""
    echo "do nothing" >/dev/null 2>&1
    write_and_exit "$errors" "do_nothing"
}

with_loading() {
    local step_name="$1"
    local function_to_run="$2"
    local ttl="${3:-3600}"
    local timeout_callback_function="$4"
    local indentation_level="${5:-1}"
    local errors=""
    local elapsed_location="$SHARED/$function_to_run.elapsed"

    local indentation=""
    for ((i=1; i<=indentation_level; i++)); do
        indentation+="\t"
    done

    # Determine the character based on the indentation level
    local prefix=''
    if [ $((indentation_level % 2)) -eq 1 ]; then
        prefix='-'
    else
        prefix='*'
    fi

    show_loading_animation "$step_name" "$function_to_run" "$indentation_level" &
    animation_pid=$!

    # Run the command in the background
    $function_to_run 2>&1 &
    # Get the process ID
    pid=$!

    # Check if the process is still running
    local elapsed=0
    local timedout="false"
    while ps -p $pid > /dev/null; do
        sleep 1

        tmp_elapsed=$(<"$elapsed_location")
        # Check if tmp_elapsed is an integer
        if [[ "$tmp_elapsed" =~ ^[0-9]+$ ]]; then
            elapsed=$tmp_elapsed
        fi
        if [ "$elapsed" -gt "$ttl" ]; then
            timedout="true"
            # Terminate the process
            kill $pid
            wait $pid 2>/dev/null
            errors+="Process couldn't be finalized in a defined TTL\n"
            break
        fi
    done

    if [[ $timedout == "false" ]]; then
        wait $pid
        local exit_status=$?

        if [[ $exit_status -ne 0 ]]; then
            errors=$(cat $DEPLOYMENT_DIR/errors/$function_to_run)
        fi
    fi

    # Terminate the loading animation
    kill $animation_pid
    wait $animation_pid 2>/dev/null

    if [ -n "$errors" ]; then
        if [[ $timedout == "true" ]];then
            echo -e "\r$indentation$prefix [${BOLD_WHITE_ON_ORANGE}timeout${NC}] $step_name $CLEARUP"

            # Check if a timeout callback function is provided
            if [ -n "$timeout_callback_function" ]; then
                # Call the custom timeout callback function
                $timeout_callback_function
            fi
        else
            SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/$function_to_run.log"
            PROCESS_LOGS_MESSAGE_SUFFIX=""
            if [ -f "$SYNTHO_CLI_PROCESS_LOGS" ]; then
                mkdir -p /tmp/syntho
                cp "$SYNTHO_CLI_PROCESS_LOGS" /tmp/syntho/.
                PROCESS_LOGS_MESSAGE_SUFFIX=" (More detail can be found here: /tmp/syntho/$function_to_run.log)"
            fi

            echo -e "\r$indentation$prefix [${BOLD_WHITE_ON_RED}failed${NC}] $step_name$PROCESS_LOGS_MESSAGE_SUFFIX $CLEARUP"
        fi

        echo -e "\n${RED}Errors:${NC}"
        echo -e "$errors\n"
        exit 1
    else
        echo -e "\r$indentation$prefix [${BOLD_WHITE_ON_GREEN}done${NC}] $step_name $CLEARUP"
    fi
}


write_and_exit() {
    local errors="$1"
    local func_name="$2"
    mkdir -p $DEPLOYMENT_DIR/errors
    if [[ $errors != "" ]]; then
        echo $errors > $DEPLOYMENT_DIR/errors/$func_name
        exit 1
    fi
    exit 0
}
