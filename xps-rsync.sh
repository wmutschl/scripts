#!/bin/bash
# I run this script with WSL2
# sudo mount -t drvfs -o uid=1000,gid=1000 D: /mnt/d #sometimes needed before plugging in
TARGET=/mnt/d/andre
for i in Apple Desktop Documents Downloads Dropbox Music Pictures Videos
do
  sudo rsync -avuP --delete /mnt/c/Users/andre/$i $TARGET/
done

TARGET=/mnt/d/micro
for i in Apple Desktop Documents Downloads Music Pictures Videos SofortUpload Work Zotero huawei
do
  sudo rsync -avuP --delete /mnt/c/Users/micro/$i $TARGET/
done
