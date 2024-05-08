#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

CUSTOM_ENV_FILE_PATH="$CUSTOM_ENV_FILE_PATH"
# shellcheck disable=SC1090
source "$CUSTOM_ENV_FILE_PATH" --source-only


ENV_VALUES=$'\tTrusted Registry: '"$TRUSTED_REGISTRY"$'\n\tArch: '"$ARCH"$'\n\tSyntho Version: '"$VERSION"

while true; do
    read -p $'\t- Please confirm if the given values are correct. (Y/n) \n\n'"$ENV_VALUES"$'\n: ' ACKNOWLEDGE
    ACKNOWLEDGE=${ACKNOWLEDGE:-Y}

    case "$ACKNOWLEDGE" in
        [nN])
            break
            ;;
        [yY])
            break
            ;;
        *)
            echo "Invalid input. Please enter 'n', 'N', 'y', or 'Y'."
            ;;
    esac
done


if ! [[ "$ACKNOWLEDGE" == "Y" || "$ACKNOWLEDGE" == "y" ]]; then
    exit 1
fi

while true; do
    read -p $'\t- Please confirm if the the trusted registry ('"$TRUSTED_REGISTRY"') is already authenticated with docker. (Y/n): ' ACKNOWLEDGE2
    ACKNOWLEDGE2=${ACKNOWLEDGE2:-Y}

    case "$ACKNOWLEDGE2" in
        [nN])
            break
            ;;
        [yY])
            break
            ;;
        *)
            echo "Invalid input. Please enter 'n', 'N', 'y', or 'Y'."
            ;;
    esac
done

if ! [[ "$ACKNOWLEDGE2" == "Y" || "$ACKNOWLEDGE2" == "y" ]]; then
    exit 1
fi
