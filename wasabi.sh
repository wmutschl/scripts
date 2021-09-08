#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$WASABI_BASEURL
curl -s --retry 3 $baseurl/start  > /dev/null
url=$baseurl

echo " "
echo "Backing up $WASABI_BTRFS_SUBVOLUME_PATH to WASABI"

btrfs subvolume snapshot -r $WASABI_BTRFS_SUBVOLUME_PATH "${WASABI_BTRFS_SUBVOLUME_PATH}_wasabi"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic cache --cleanup
restic backup "${WASABI_BTRFS_SUBVOLUME_PATH}_wasabi"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic snapshots
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
btrfs subvolume delete "${WASABI_BTRFS_SUBVOLUME_PATH}_wasabi"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi

echo " "
echo "HealthChecks.io:"
echo $url
curl -s --retry 3 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
