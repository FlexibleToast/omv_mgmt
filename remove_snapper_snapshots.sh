#!/bin/bash

configs=$(ls -1 /etc/snapper/configs | grep disk)

for config in ${configs}
  do
  echo "Disabling timeline snapshots for ${config}"
  sed -i "s/TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/g" /etc/snapper/configs/${config}
  mount=$(lsblk -o label,mountpoint | grep ${config} | awk '{print $2}')
  snapshots=$(ls -1 ${mount}/.snapshots)
  for snapshot in ${snapshots}
    do
    snapper -c ${config} delete ${snapshot} 2> /dev/null || echo "Config: ${config}; Snapshot: ${snapshot}; Mount: ${mount} ecnountered an error"
  done
done
