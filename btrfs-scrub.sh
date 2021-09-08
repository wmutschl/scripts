#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$BTRFS_SCRUB_BASEURL
url=$baseurl
curl -s -m 10 --retry 5 $url/start > /dev/null

echo " "
# Priority of IO at which the scrub process will run. Idle should not degrade performance but may take longer to finish.
BTRFS_SCRUB_PRIORITY="normal"
# Do read-only scrub and don't try to repair anything.
BTRFS_SCRUB_READ_ONLY="false"

readonly=
if [ "$BTRFS_SCRUB_READ_ONLY" = "true" ]; then
  readonly=-r
fi
ioprio=
if [ "$BTRFS_SCRUB_PRIORITY" = "normal" ]; then
  # ionice(3) best-effort, level 4
  ioprio="-c 2 -n 4"
fi

for MNT in $BTRFS_MOUNTPOINTS; do
  echo "Running scrub on $MNT"
  #btrfs scrub status "$MNT"
  btrfs scrub start -Bd $ioprio $readonly "$MNT"
  if [ "$?" != "0" ]; then
    echo "Scrub cancelled at $MNT"
    url=$baseurl/fail
  fi
  echo ""
done

echo " "
echo "HealthChecks.io:"
echo $url
curl -s -m 10 --retry 5 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
