#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "
echo "Pruning and checking restic repo on WASABI"

restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 1 --prune
restic check --read-data
echo " "
echo "Finished"
echo "*****************************************************"
