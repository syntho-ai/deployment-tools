#!/bin/bash

# Declare animation_pid as a global variable
animation_pid=""

cleanup() {
    # This function is called when the script is interrupted (e.g., Ctrl+C).
    if [ -n "$animation_pid" ]; then
        kill "$animation_pid"  # Terminate the loading animation
    fi
    exit 1
}

trap cleanup INT  # Set up the trap to call the cleanup function on Ctrl+C

show_loading_animation() {
    local dots=""
    local i=0
    echo -n -e "\t- $1$dots"
    
    while true; do
        sleep 0.5
        i=$(( (i+1) % 4 ))
        dots="${dots}."
        echo -n -e "\r\t- $1$dots"
    done
}

command_exists() {
    type "$1" &> /dev/null
}


with_loading() {
    local step_name="$1"
    local function_to_run="$2"

    show_loading_animation "$step_name" &
    animation_pid=$!

    errors=$($function_to_run 2>&1)

    # Terminate the loading animation
    kill $animation_pid
    wait $animation_pid 2>/dev/null

    if [ -n "$errors" ]; then
        # If there are errors, print "failed" and the error message
        echo -e "\r\t- $step_name failed."
        echo -e "\nErrors:"
        echo -e "$errors"
        exit 1
    else
        # If the function runs without errors, print "done"
        echo -e "\r\t- $step_name done."
    fi
}
