#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)

export RESTIC_REPOSITORY=${RESTIC_PRUNE_PATH}

echo "Pruning restic repo: $RESTIC_REPOSITORY"
restic cache --cleanup
#restic forget --keep-last 1 --prune
restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 1 --prune
restic cache --cleanup
echo " "
echo "Finished"
echo "*****************************************************"
