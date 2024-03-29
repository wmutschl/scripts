#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)

export RESTIC_REPOSITORY=${RESTIC_CHECK_PATH}

echo " "
echo "Checking restic repo: $RESTIC_REPOSITORY"

restic cache --cleanup
#restic check
restic check --read-data
#restic check --read-data-subset=1/5
#restic check --read-data-subset=2/5
#restic check --read-data-subset=3/5
#restic check --read-data-subset=4/5
#restic check --read-data-subset=5/5
restic cache --cleanup

echo " "
echo "Finished"
echo "*****************************************************"
