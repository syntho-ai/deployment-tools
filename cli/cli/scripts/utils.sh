#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"

RED='\033[0;31m'
BOLD_WHITE_ON_RED='\033[1;37;41m'
GREEN='\033[0;32m'
BOLD_WHITE_ON_GREEN='\033[1;37;42m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
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
    exit 1
}

# Set up the trap to call the cleanup function on Ctrl+C
trap cleanup INT

show_loading_animation() {
    start_time=$(date +%s)
    latest_elapsed_time="00:00:00"

    local func_name="$2"
    local sleep_duration="0.5"
    local spinner="/-\\|"
    local spinner_length=${#spinner}
    local spinner_index=0

    echo -n -e "\t- [00:00:00] $1 ${spinner:0:1}"

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

        echo -n -e "\r\t- [$latest_elapsed_time] $1 $spinner_char"

        spinner_index=$(( (spinner_index + 1) % spinner_length ))

        sleep $sleep_duration
    done
}

command_exists() {
    type "$1" &> /dev/null
}

default_timeout_callback() {
    echo "do nothing"
}

with_loading() {
    local step_name="$1"
    local function_to_run="$2"
    local ttl="${3:-3600}"
    local timeout_callback_function="$4"
    local errors=""
    local elapsed_location="$SHARED/$function_to_run.elapsed"

    show_loading_animation "$step_name" "$function_to_run" &
    animation_pid=$!

    # Run the command in the background
    $function_to_run 2>&1 &
    # Get the process ID
    pid=$!

    # Check if the process is still running
    local timedout="false"
    while ps -p $pid > /dev/null; do
        sleep 1

        elapsed=$(<"$elapsed_location")
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
        # Process has completed, check the exit status
        if ! wait $pid; then
            errors=$(wait $pid 2>&1)
        fi
    fi

    # Terminate the loading animation
    kill $animation_pid
    wait $animation_pid 2>/dev/null

    if [ -n "$errors" ]; then
        echo -e "\r\t- [${BOLD_WHITE_ON_RED}failed${NC}] $step_name $CLEARUP"
        echo -e "\n${RED}Errors:${NC}"

        echo -e "$errors\n"

        exit 1
    else
        echo -e "\r\t- [${BOLD_WHITE_ON_GREEN}done${NC}] $step_name $CLEARUP"
    fi
}
