#!/bin/bash
eval $(grep -v -e '^#' /home/wmutschl/scripts/.env | xargs -I {} echo export \'{}\')
echo "*****************************************************"
echo $(date)
echo " "

rclone --config $WASABI_RCLONE_CONF sync wasabi:$WASABI_BUCKET $EXTERNAL_HDD/$WASABI_BUCKET -P
if [ $? -ne 0 ]; then url=$baseurl/fail; fi
