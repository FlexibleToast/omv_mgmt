#!/bin/bash

for dataset in $(zfs list -H -o name | grep ${1:-tank0} | grep -v .system)
	do
	size=$(zfs get all $dataset | grep usedbysnapshot | awk '{print $3}')
	[[ $size != 0 ]] && printf "%-50s %10s\n" $dataset $size
done
