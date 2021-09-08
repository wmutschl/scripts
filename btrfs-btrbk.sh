#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

baseurl=$BTRBK_BASEURL
url=$baseurl
curl -s -m 10 --retry 5 $url/start > /dev/null

echo " "
echo "Running btrbk"
/usr/bin/btrbk -c $BTRBK_CONFFILE run
if [ $? -ne 0 ]; then url=$baseurl/fail; fi

echo " "
echo "HealthChecks.io:"
echo $url
curl -s -m 10 --retry 5 $url > /dev/null
echo " "
echo $(date)
echo "Finished"
echo "*****************************************************"
