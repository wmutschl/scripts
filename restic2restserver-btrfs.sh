#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$RESTSERVER_BASEURL
curl -s --retry 3 $baseurl/start  > /dev/null
url=$baseurl

export RESTIC_REPOSITORY="rest:${RESTSERVER_PROTOCOL}://${RESTSERVER_USER}:${RESTSERVER_PASSWORD}@${RESTSERVER_URL}:${RESTSERVER_PORT}/${RESTSERVER_USER}"
export RESTIC_PASSWORD=$RESTSERVER_RESTIC_PASSWORD

echo " "
echo "Backing up $RESTSERVER_SUBVOLUMES to REST SERVER"
btrfs subvolume snapshot -r $RESTSERVER_SUBVOLUMES "${RESTSERVER_SUBVOLUMES}_rest"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic cache --cleanup
restic backup "${RESTSERVER_SUBVOLUMES}_rest"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic snapshots
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
btrfs subvolume delete "${RESTSERVER_SUBVOLUMES}_rest"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic cache --cleanup

echo " "
echo "HealthChecks.io:"
echo $url
curl -s --retry 3 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
