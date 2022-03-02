#!/bin/bash
systemctl stop minio
systemctl disable minio
wget https://dl.minio.io/server/minio/release/linux-amd64/minio
chown user-minio. minio
chmod +x minio
mv minio /usr/local/bin
systemctl reset-failed minio
systemctl enable minio
systemctl start minio
systemctl status minio
