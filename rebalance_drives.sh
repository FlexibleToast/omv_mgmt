#!/bin/bash
set -eu

configs=$(ls -1 /etc/snapper/configs | grep disk)
percent=0.25
pool=/srv/mergerfs/backend
tools=/root/mergerfs-tools/src

echo "Stopping snapper from making timeline snapshots"
pushd /etc/snapper/configs
sed -i "s/TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/g" ${configs}

echo "Dedup mergerfs"
dedup_result=$(${tools}/mergerfs.dedup -v -D .snapshots -D snapraid --dedup=newest ${pool} | tee /dev/tty)
savings=$(echo ${dedup_result} | tail -n 1 | cut -d ' ' -f 4)
if [[ $savings != "0.0B" ]]
  then
  read -p "Perform dedup? [y/N] " dedup
  [[ ${dedup} =~ ^(y|Y|yes|Yes)$ ]] && ${tools}/mergerfs.dedup -e -D .snapshots -D snapraid --dedup=newest ${pool}
fi

echo "Remove current snapper snapshots"
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

echo "Rebalance data"
${tools}/mergerfs.balance -p ${percent} ${pool}

echo "Sync snapraid"
snapraid-btrfs sync

echo "Re-enable timeline snapshots"
sed -i "s/TIMELINE_CREATE=\"no\"/TIMELINE_CREATE=\"yes\"/g" $(ls -1 /etc/snapper/configs | grep disk)
popd
