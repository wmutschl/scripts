#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$EXTERNAL_RESTIC_BASEURL
curl -s --retry 3 $baseurl/start  > /dev/null
url=$baseurl

echo " "
echo "Backing up $EXTERNAL_RESTIC_BTRFS_SUBVOLUME_PATH to $RESTIC_REPOSITORY"

btrfs subvolume snapshot -r $EXTERNAL_RESTIC_BTRFS_SUBVOLUME_PATH "${EXTERNAL_RESTIC_BTRFS_SUBVOLUME_PATH}_restic"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic cache --cleanup
restic backup "${EXTERNAL_RESTIC_BTRFS_SUBVOLUME_PATH}_restic"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic snapshots
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
btrfs subvolume delete "${EXTERNAL_RESTIC_BTRFS_SUBVOLUME_PATH}_restic"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi

echo " "
echo "HealthChecks.io:"
echo $url
curl -s --retry 3 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
