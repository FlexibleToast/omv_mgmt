#!/bin/bash

if [ $# != 3 ] && [ $# != 4 ]; then
  echo "usage: $0 <cache-drive> <backing-pool> <percentage> <target percentage (optional)>"
  exit 1
fi

if [ $# -eq 4 ] && [ "$4" -ge "$3" ]; then
  echo "<target percentage> must be smaller than <percentage>"
  exit 1
fi

CACHE="${1}"
BACKING="${2}"
PERCENTAGE=${3}
TARGET_PERCENTAGE=${4:-$3}

set -o errexit

# Move files from CACHE to BACKING
if [ $(df --output=pcent "${CACHE}" | grep -v Use | cut -d'%' -f1) -gt ${PERCENTAGE} ]
then
  PRE_MOVE=$(mktemp)
  POST_MOVE=$(mktemp)
  # Get list of files currently on the CACHE
  find ${CACHE} -type f | sort > ${PRE_MOVE}
  ATIME_SORTED_LIST=$(find "${CACHE}" -type f -printf '%A@ %P\n' | sort | cut -d' ' -f2-)
  while IFS= read -r file
  do
    if [ $(df --output=pcent "${CACHE}" | grep -v Use | cut -d'%' -f1) -gt ${TARGET_PERCENTAGE} ]
      then
      test -n "${file}"
      rsync -axqHAXWESR --preallocate --remove-source-files "${CACHE}/./${file}" "${BACKING}/"
    else
      echo "Finished"
      break
    fi
  done <<< "${ATIME_SORTED_LIST}"
  # Get the difference between pre and post and email results
  find ${CACHE} -type f | sort > ${POST_MOVE}
  comm -2 -3 ${PRE_MOVE} ${POST_MOVE} | mail -s "Files moved from ${CACHE} to ${BACKING}" JMcDade42@gmail.com
  # Cleanup
  rm ${PRE_MOVE} ${POST_MOVE}
fi
