#!/bin/bash
set -eu

##################### FUNCTION DEFINITIONS #########################
parse_args() {
  # Set default values for options
  configs=(/etc/snapper/configs/disk*)
  percent=0.25
  pool="/srv/mergerfs/backend"
  tools="/root/mergerfs-tools/src"

  # Use getopt to parse command line arguments
  ARGS=$(getopt -o hc:p:l:t: --long help,config:,percent:,pool:,tools: --name "$(basename "$0")" -- "$@")
  # Get the command line arguments and assign them to variables according to their corresponding flags
  # h: -> means the -h flag needs an argument
  # l -> means the -l flag doesn't have an argument 
  # "hc:p:l:t:" -> all the possible flags

  eval set -- "${ARGS}"  # This sets positional parameters to the arguments that were used in getopt

  while true; do  # Start loop to go through all command line arguments
    case "${1}" in  
      -h|--help)  # Show usage information and exit
        echo "Usage: $(basename "$0") [-c configs] [-p percent] [-l pool] [-t tools]"
        exit 0
        ;;
      -c|--configs)  # Change default configuration files to be used
        configs=(${2})
        shift 2
        ;;
      -p|--percent)  # Change rebalance percentage
        percent="${2}"
        shift 2
        ;;
      -l|--pool)  # Change path to mergerfs mount point
        pool="${2}"
        shift 2
        ;;
      -t|--tools)  # Change path to mergerfs tool binaries
        tools="${2}"
        shift 2
        ;;
      --)  # End of arguments
        shift
        break
        ;;
      *)  # Error if an invalid argument is received
        echo "Error: Invalid option ${1}"
        exit 1
        ;;
    esac
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

remove_snapper_snapshots() {
  local configs=("$@")
  for config in "${configs[@]}"; do
    label=$(basename "$config")
    mountpoint=$(lsblk -o NAME,LABEL,MOUNTPOINT | awk -v label="$label" '$2 == label { print $3 }')
    printf 'Removing current snapper snapshots for config %s...\n' "$label"
    while IFS= read -r -d '' snapshot; do
      if ! snapper -c "$label" delete "$snapshot"; then
        printf 'Error: could not delete snapshot %s\n' "$snapshot" >&2
      fi
    done < <(find "$mountpoint/.snapshots" -mindepth 1 -maxdepth 1 -type d -printf '%f\0' 2>/dev/null || true)
  done
}

dedup_mergerfs() {
  local tools="$1"
  local pool="$2"

  printf 'Dedup mergerfs\n'
  dedup_result=$("${tools}/mergerfs.dedup" -v -D .snapshots -D snapraid --dedup=newest "${pool}" | tee /dev/tty)
  savings=$(echo "${dedup_result}" | tail -n 1 | awk '{print $4}')
  if [ "${savings%.*}" -gt 0 ]; then
    read -p "Perform dedup? [y/N] " dedup
    [[ "${dedup}" =~ ^(y|Y|yes|Yes)$ ]] && "${tools}/mergerfs.dedup" -e -D .snapshots -D snapraid --dedup=newest "${pool}"
  fi
}

rebalance_data() {
  local tools="$1"
  local percent="$2"
  local pool="$3"

  printf 'Rebalance data\n'
  "${tools}/mergerfs.balance" -p "${percent}" "${pool}"
}

# Function to remove old SnapRAID data files
remove_snapraid_data() {
  printf 'Cleanup old snapraid data\n'
  find /srv/ -type f -name snapraid.content -delete
}

# Function to sync SnapRAID parity
sync_snapraid_parity() {
  printf 'Sync snapraid\n'
  snapraid-btrfs sync
}

##################### MAIN SCRIPT ###################################

# Call function to parse command line arguments
parse_args "$@"

# Call each function separately
disable_snapper ${configs[@]}
dedup_mergerfs ${tools} ${pool}
remove_snapper_snapshots ${configs[@]}
remove_snapraid_data
rebalance_data ${tools} ${percent} ${pool}
sync_snapraid_parity
enable_snapper ${configs[@]}