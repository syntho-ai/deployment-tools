#!/bin/bash

if [ -z "$DEPLOYMENT_DIR" ]; then
  of echo "Error: DEPLOYMENT_DIR is not set"
    exit 1
fi

if [ -z "$PARAMS" ]; then
    echo "Error: PARAMS is not set"
    exit 1
fi

source $DEPLOYMENT_DIR/.env --source-only

if [ -z "$KUBECONFIG" ]; then
    echo "Error: KUBECONFIG is not set"
    exit 1
fi

output=$(eval "kubectl --kubeconfig \"$KUBECONFIG\" get $PARAMS" 2>&1)

if [ $? -eq 0 ]; then
    output="${output%\"}"
    output="${output#\"}"
    echo "$output"
else
    if [[ $output == "Error from server (NotFound):"*"not found" ]]; then
        exit 0
    else
        # If the error message does not match, print the error message and return exit code 1
        >&2 echo "$output"
        exit 1
    fi
fi
