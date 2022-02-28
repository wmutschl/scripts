sudo systemctl stop minio
sudo systemclt disable minio
wget https://dl.minio.io/server/minio/release/linux-amd64/minio
sudo chown user-minio. minio
sudo chmod +x minio
sudo mv minio /usr/local/bin
sudo systemctl enable minio
sudo systemctl start minio
