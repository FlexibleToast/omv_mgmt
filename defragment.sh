#!/bin/bash

set -e

defrag() {
	while read -r disk
	do
		label=$(cut -f 1 -d ' ' <<< ${disk})
		mount=$(cut -f 4 -d ' ' <<< ${disk})
		echo "btrfs defrag ${label} at ${mount}"
		btrfs filesystem defragment -r ${mount}
	done <<< $(lsblk -o label,mountpoint | grep '^disk-*' | grep -v 'disk-11' | sort)
	echo Completed
}

time defrag

python3 '/root/snapraid-btrfs-runner/snapraid-btrfs-runner.py' --conf '/root/snapraid-btrfs-runner/snapraid-btrfs-runner.conf'
