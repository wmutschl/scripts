#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)

export RESTIC_REPOSITORY=$EXTERNAL_PATH/btrfs_docker/@docker
export RESTIC_PASSWORD=$EXTERNAL_RESTIC_PASSWORD

echo " "
echo "Checking restic repo: $RESTIC_REPOSITORY"

#restic check
restic check --read-data
#restic check --read-data-subset=1/5
#restic check --read-data-subset=2/5
#restic check --read-data-subset=3/5
#restic check --read-data-subset=4/5
#restic check --read-data-subset=5/5

echo " "
echo "Finished"
echo "*****************************************************"
