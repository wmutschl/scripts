#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)

export RESTIC_REPOSITORY=$EXTERNAL_PATH/btrfs_docker/@docker
export RESTIC_PASSWORD=$EXTERNAL_RESTIC_PASSWORD

echo "Pruning restic repo: $RESTIC_REPOSITORY"

restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 1 --prune

echo " "
echo "Finished"
echo "*****************************************************"
