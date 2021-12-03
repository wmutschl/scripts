#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "
echo "Checking restic repo: $RESTIC_REPOSITORY"
restic check --read-data
echo " "
echo "Finished"
echo "*****************************************************"
