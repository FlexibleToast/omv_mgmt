#!/bin/bash
set -eu

##################### FUNCTION DEFINITIONS #########################
parse_args() {
  # Set default values for options
  src_pool="/srv/mergerfs/drain"
  dest_pool="/srv/mergerfs/backend"

  # Use getopt to parse command line arguments
  ARGS=$(getopt -o hs:d: --long help,source:,dest: --name "$(basename "$0")" -- "$@")
  # Get the command line arguments and assign them to variables according to their corresponding flags
  # h: -> means the -h flag needs an argument
  # l -> means the -l flag doesn't have an argument

  eval set -- "${ARGS}"  # This sets positional parameters to the arguments that were used in getopt

    while true; do  # Start loop to go through all command line arguments
        case "${1}" in  
        -h|--help)  # Show usage information and exit
            echo "Usage: $(basename "$0") [-s source] [-d destination]"
            exit 0
            ;;
        -s|--source)  # drain source
            src_pool="${2}"
            readonly src_pool
            shift 2
            ;;
        -d|--dest)  # drain destination
            dest_pool="${2}"
            readonly dest_pool
            shift 2
            ;;
        --)  # End of arguments
            shift
            break
            ;;
        *)  # Error if an invalid argument is received
            echo "Error: Invalid option ${1}"
            echo "Usage: $(basename "$0") [-s source] [-d destination]"
            exit 1
            ;;
        esac
    done
}

move_data(){
    echo "******************** Moving Data ********************"
    if ! rsync -avlHAXWE --preallocate --exclude=snapraid --exclude=.snapshots --progress --remove-source-files "${src_pool}/" "${dest_pool}"; then
        echo "Error: rsync failed to move data"
        exit 1
    fi
}

sync_snapraid(){
    echo "******************** Performing SnapRAID dsync ********************"
    snapraid-btrfs dsync
    echo "******************** Cleaning up SnapRAID ********************"
    snapraid-btrfs cleanup 2> /dev/null
}


##################### MAIN #########################

parse_args "$@"
sync_snapraid
time move_data
sync_snapraid
