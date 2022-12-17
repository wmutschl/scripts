#!/bin/bash
eval $(grep -v -e '^#' /home/ubuntu/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$MINIO_BASEURL
curl -s --retry 3 $baseurl/start  > /dev/null
url=$baseurl

export RESTIC_REPOSITORY=${MINIO_PATH}
export RESTIC_PASSWORD=$MINIO_RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID=$MINIO_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$MINIO_AWS_SECRET_ACCESS_KEY

echo " "
restic cache --cleanup
restic backup "${MINIO_DIR}"
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
restic snapshots
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
