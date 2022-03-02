# Backup and Installation Scripts
These are the scripts I use for my [backup strategy](https://mutschler.eu/linux/backup) and my [installation guides](https://mutschler.eu/linux/install-guides).

## .env files
Copy the machine specific env file and name it `.env`.

## Crontab
You can overwrite the current crontab with the machine specific one:
```sh
sudo crontab xyz-crontab.txt
```
Note to adjust the healthchecks.io ping address.

## Container settings

### Swag container
After starting the [SWAG container](https://docs.linuxserver.io/general/swag), change the security settings in the `$HOME/docker/swag/nginx/ssl.conf` file. That is, enable HSTS and uncomment all optional headers for additional security, see this [post for more information](https://discourse.linuxserver.io/t/further-discussion-on-optional-swag-headers/3367).

### Gitea settings
My settings are given in the gitea.app.ini file. This needs to be renamed to app.ini and moved into the gitea directory.

## Systemd timers for btrbk
For machines that don't run constantly I use a systemd timer for `btrbk` instead of `cron`:

```
sudo cp $HOME/scripts/btrfs-btrbk-systemd.timer /lib/systemd/system/btrfs-btrbk-systemd.timer
sudo cp $HOME/scripts/btrfs-btrbk-systemd.service /lib/systemd/system/btrfs-btrbk-systemd.service
sudo chmod 644 /lib/systemd/system/btrfs-btrbk-systemd.timer
sudo chmod 644 /lib/systemd/system/btrfs-btrbk-systemd.service
mkdir -p $HOME/logs
```
Now let's test it first:
```
sudo systemctl start btrfs-btrbk-systemd.service
sudo systemctl status btrfs-btrbk-systemd.service
cat /var/log/btrbk.log
cat $HOME/logs/btrfs-btrbk.log
```
Check if snapshots are created and if any errors occured. If all is well, then enable the timer:
```
sudo systemctl enable btrfs-btrbk-systemd.timer
sudo systemctl start btrfs-btrbk-systemd.timer
sudo systemctl daemon-reload
sudo systemctl list-timers --all
```
You should see the timer enabled:
```
NEXT                         LEFT           LAST                         PASSED             UNIT                      >
Fri 2021-09-10 10:00:00 CEST 36min left     n/a                          n/a                btrfs-btrbk-systemd.timer >
```
Recheck the houerly timer after an hour to make sure everything is working:
```
sudo systemctl list-timers --all
cat /var/log/btrbk.log
cat $HOME/logs/btrfs-btrbk.log
``` 

## Restic and MinIO
### Install MinIO on Ubuntu Server
Source: [How to Install minio S3 Compatible Object Storage on Ubuntu 20.04](https://vitux.com/how-to-install-minio-s3-compatible-object-storage-on-ubuntu-20-04/)

#### 1. Create User for MinIO
First of all, let’s create a new user which will manage the MinIO server. For security reasons, it might not be good practice to run a MinIO server under a regular sudo user or root user. so, we will create a user with no shell access:
```bash
sudo useradd --system user-minio -s /bin/false
```

#### 2. Installing MinIO Server
To download binary file run:
```bash
wget https://dl.minio.io/server/minio/release/linux-amd64/minio
```
Then, change the ownership of the binary file to a newly created user. So run:
```bash
sudo chown user-minio. minio
```
Now, give the executable permission for the MinIO binary file we just downloaded using the following command.
```bash
sudo chmod +x minio
```
Once execute permission is granted, move the binary file to the directory where all system application binary is expected to be:
```bash
sudo mv minio /usr/local/bin
```

#### 3. Configuring MinIO Server
Usually, all the system program configuration files are stored in the /etc directory so, let’s create the directory that contains our MinIO configuration file and also create a directory for storing the buckets that we upload to the MinIO server. In this article, I have named both the dir as MinIO.
```bash
sudo mkdir /etc/minio /user/local/share/minio
```
Now, change the ownership of the MinIO directory that we just created to user-minio using the following command.
```bash
sudo chown user-minio. /etc/minio
sudo chown user-minio. /usr/local/share/minio
```
Next, open the file in the following location named MinIO so we can override the default configuration.
```bash
sudo nano /etc/default/minio
```
Then, copy-paste the following configuration in the file.
```
MINIO_ROOT_USER="XYZUSER"
MINIO_ROOT_PASSWORD="XYZPASSWORD"
MINIO_VOLUMES="/home/minio/"
MINIO_OPTS="-C /etc/minio --address XXX.XX.XX.XX:9000 --console-address XXX.XX.XXX.XXX:9001"
```
Where I use my tailscale address for the server. Once everything is configured, write and quit the file.

#### 4. Configure UFW Firewall
I don't need to do this as I am establishing the connection using Tailscale and have set up [UFW to lock down an Ubuntu server](https://tailscale.com/kb/1077/secure-server-ubuntu-18-04).

#### 5. MinIO Systemd unit file
In order to manage MinIO by systemd, we need to add the MinIO service descriptor file in the systemd configuration dir. To download the file execute:
```bash
wget https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
```
Once the file is downloaded you can view the file. Mine looks like this:
```
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local/

User=user-minio
Group=user-minio
ProtectProc=invisible

EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

# Let systemd restart this service always
Restart=always

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=1048576

# Specifies the maximum number of threads this process can create
TasksMax=infinity

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

# Built for ${project.name}-${project.version} (${project.name})
```
This is basically the default except a different user and group.

Now, move the service file to the systemd configuration directory using the following command:
```bash
sudo mv minio.service /etc/systemd/system
```
After you move the file reload systemd daemon:
```bash
sudo systemctl daemon-reload
```
Now, you can manage the MinIO using the systemctl command. To enable autostart of the service and to actually start MinIO run:
```bash
sudo systemctl enable minio
sudo systemctl start minio
```
Check the status with
```bash
sudo systemctl status minio
```
You can exit this with `:q` or `CTRL`+`C`. If you are unable to start the MinIO service due to a `Start request repeated too quickly` error, run `sudo systemctl reset-failed minio` and restart the service. Check the status and all should be good.


#### 6. Accessing MinIO’s Web Interface
Now we can access the MinIO interface using our Tailscale IP address with the port 9000 from any computer connected to the Tailscale Mesh network, e.g. `https://XXX.XX.XX.XX:9000`. Log in with the credentials from the config file and set up a bucket and corresponding access and private keys.

#### 7. Update MinIO
For updates I use the script `update-minio.sh`.

### Restic
We can now easily use Restic and [prepare a new repo or access an old one](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#minio-server). The script I use for backup purposes is `restic2minio.sh`, where the keys are stored in my `.env` file (see simba.env for an example).

## Rclone and Wasabi (depreciated)
Install rclone and connect it to your Wasabi bucket. I use `wasabi-rclone.conf` as configuration file. After including my AWS Access and Secret Access keys, I copy it as `.wasabi-rclone.conf`.
