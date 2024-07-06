#!/bin/bash
set -euo pipefail

##################### FUNCTION DEFINITIONS #########################
parse_args() {
  # Set default values for options
  configs=(/etc/snapper/configs/disk*)
  disable=false
  enable=false

  # Use getopt to parse command line arguments
  ARGS=$(getopt -o hc:ed --long help,config:,enable,disable --name "$(basename "$0")" -- "$@")
  # Get the command line arguments and assign them to variables according to their corresponding flags
  # h: -> means the -h flag needs an argument
  # l -> means the -l flag doesn't have an argument 
  # "hc:e:d:" -> all the possible flags

  eval set -- "${ARGS}"  # This sets positional parameters to the arguments that were used in getopt

  while true; do
    case "${1}" in
      -h|--help)
        echo "Usage: $(basename "$0") [-c configs] [--enable | --disable]"
        exit 0
        ;;
      -c|--configs)
        configs=(${2})
        shift 2
        ;;
      -d|--disable)
        disable=true
        shift 1
        ;;
      -e|--enable)
        enable=true
        shift 1
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Error: Invalid option ${1}"
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

# Call functions based on command line arguments.
parse_args "$@"
[[ $disable == true ]] && disable_snapper "${configs[@]}"
remove_snapper_snapshots "${configs[@]}"
[[ $enable == true ]] && enable_snapper "${configs[@]}"