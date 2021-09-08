#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$NEXTCLOUD_MAINTENANCE_BASEURL
url=$baseurl
curl -s -m 10 --retry 5 $url/start > /dev/null

echo " "
echo "Running maintenance scripts"

occ="docker exec -i nextcloud occ"
$occ db:add-missing-columns
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ db:add-missing-indices
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ db:add-missing-primary-keys
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ db:convert-filecache-bigint
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ app:update --all
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ files:scan-app-data
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
$occ files:scan --all
if [ $? -ne 0 ]; then url=$baseurl/fail; fi

echo " "
echo "HealthChecks.io:"
echo $url
curl -s -m 10 --retry 5 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
