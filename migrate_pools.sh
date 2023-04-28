#!/bin/bash
set -eu

merged_pool=/srv/mergerfs/backend
shrunk_pool=/srv/mergerfs/shrunk
remove_pool=/srv/mergerfs/remove

echo "Stopping snapper from making timeline snapshots"
pushd /etc/snapper/configs
sed -i "s/TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/g" $(ls -1 /etc/snapper/configs | grep disk)

echo "Remove current snapper snapshots"
configs=$(ls -1 /etc/snapper/configs | grep disk)

for config in ${configs}
  do
  mount=$(lsblk -o label,mountpoint | grep ${config} | awk '{print $2}')
  snapshots=$(ls -1 ${mount}/.snapshots)
  for snapshot in ${snapshots}
    do
    snapper -c ${config} delete ${snapshot} 2> /dev/null || echo "Config: ${config}; Snapshot: ${snapshot}; Mount: ${mount} ecnountered an error"
  done
done

echo "Cleanup old snapraid data"
find /srv/ -type f -name snapraid.content -delete

echo "Moving data"
rsync -avlHAXWE --preallocate --exclude=snapraid --exclude=.snapshots --progress --remove-source-files ${remove_pool}/ ${shrunk_pool}

echo "Sync snapraid"
snapraid-btrfs sync

echo "Re-enable timeline snapshots"
sed -i "s/TIMELINE_CREATE=\"no\"/TIMELINE_CREATE=\"yes\"/g" $(ls -1 /etc/snapper/configs | grep disk)
popd
