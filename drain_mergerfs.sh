#!/bin/bash
set -eu

##################### FUNCTION DEFINITIONS #########################
parse_args() {
  # Set default values for options
  configs=(/etc/snapper/configs/disk*)
  src_pool="/srv/mergerfs/drain"
  dest_pool="/srv/mergerfs/backend"

  # Use getopt to parse command line arguments
  ARGS=$(getopt -o hs:d:c: --long help,source:,dest:,config: --name "$(basename "$0")" -- "$@")
  # Get the command line arguments and assign them to variables according to their corresponding flags
  # h: -> means the -h flag needs an argument
  # l -> means the -l flag doesn't have an argument

  eval set -- "${ARGS}"  # This sets positional parameters to the arguments that were used in getopt

    while true; do  # Start loop to go through all command line arguments
        case "${1}" in
        -h|--help)  # Show usage information and exit
            echo "Usage: $(basename "$0") [-s source] [-d destination] [-c snapper_config]"
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
        -c|--configs) # snapper config source
            configs="${2}"
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

# Remove current snapper snapshots for all configs.
remove_snapper_snapshots() {
  local configs=("$@")
  for config in "${configs[@]}"; do
    label=$(basename "$config")
    mountpoint=$(lsblk -o NAME,LABEL,MOUNTPOINT | awk -v label="$label" '$2 == label { print $3 }')
    printf 'Removing current snapper snapshots for config %s...\nAt mountpoint: %s\n' "$label" "$mountpoint"
    while IFS= read -r -d '' snapshot; do
      printf 'Snapshot: %s\n' "$snapshot"
      if ! snapper -c "$label" delete "$snapshot"; then
        printf 'Error: could not delete snapshot %s\n' "$snapshot" >&2
      fi
    done < <(find "$mountpoint/.snapshots" -mindepth 1 -maxdepth 1 -type d -printf '%f\0' 2>/dev/null || true)
  done
}

disable_snapper() {
  local configs=("$@")
  printf 'Disabling timeline snapshots for %s\n' "${configs[@]}"
  sed -i "s/TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/g" "${configs[@]}"
}

enable_snapper() {
  local configs=("$@")
  printf 'Re-enable timeline snapshots for %s\n' "${configs[@]}"
  sed -i "s/TIMELINE_CREATE=\"no\"/TIMELINE_CREATE=\"yes\"/g" "${configs[@]}"
}

purge_snapraid(){
    echo "***************** Purging SnapRAID ******************"
    find /srv/ -type f -name snapraid.content -delete
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
disable_snapper "${configs[@]}"
remove_snapper_snapshots "${configs[@]}"
purge_snapraid
time move_data
sync_snapraid
enable_snapper "${configs[@]}"
