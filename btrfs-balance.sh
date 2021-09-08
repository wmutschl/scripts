#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$BTRFS_BALANCE_BASEURL
url=$baseurl
curl -s -m 10 --retry 5 $url/start > /dev/null

echo " "
DUSAGES="0 5 10"
MUSAGES="0 5 10"
for MP in $BTRFS_MOUNTPOINTS; do
  for DU in $DUSAGES; do
    for MU in $MUSAGES; do
      cmd="btrfs balance start -dusage=$DU -musage=$MU $MP"
      echo $cmd
      $cmd
      if [ $? -ne 0 ]; then url=$baseurl/fail;fi
    done
  done
  btrfs filesystem df $MP
  df -H $MP
  echo " "
done

echo " "
echo "HealthChecks.io:"
echo $url
curl -s -m 10 --retry 5 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
