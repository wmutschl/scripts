#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$EXTERNAL_BASEURL
curl -s --retry 3 $baseurl/start  > /dev/null
url=$baseurl

export RESTIC_PASSWORD=$EXTERNAL_RESTIC_PASSWORD

for SUBVOL in $EXTERNAL_SUBVOLUMES; do
  export RESTIC_REPOSITORY="${EXTERNAL_PATH}${SUBVOL}"
  echo " "
  echo "Backing up $SUBVOL to ${RESTIC_REPOSITORY}"
  btrfs subvolume snapshot -r $SUBVOL "${SUBVOL}_external"
  if [ $? -ne 0 ]; then url=$baseurl/fail; fi
  restic cache --cleanup
  restic backup "${SUBVOL}_external"
  if [ $? -ne 0 ]; then url=$baseurl/fail; fi
  restic snapshots
  if [ $? -ne 0 ]; then url=$baseurl/fail; fi
  btrfs subvolume delete "${SUBVOL}_external"
  if [ $? -ne 0 ]; then url=$baseurl/fail; fi
done

echo " "
echo "HealthChecks.io:"
echo $url
curl -s --retry 3 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"