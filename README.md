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

### Docker registry
Generate a htpasswd file:
```sh
registry_user=
registry_pass=
docker run --entrypoint htpasswd registry:2 -Bbn $registry_user $registry_pass > ${DOCKER_REGISTRY_ROOT}/auth/htpasswd
```

## restic using rest-server
I am running this on a server that is only accessible via Tailscale, so the HTTP protocol is sufficient for my usecase.

### Install restic
```sh
sudo apt install restic
```

### Create system user and download rest-server
```sh
sudo adduser --system restic-server
# Find the latest release on Github
wget https://github.com/restic/rest-server/releases/download/v0.12.0/rest-server_0.12.0_linux_amd64.tar.gz
tar xzf rest-server_0.12.0_linux_amd64.tar.gz
sudo cp rest-server_0.12.0_linux_amd64/rest-server /usr/local/bin/restic-server
sudo chown root:root /usr/local/bin/restic-server
sudo chmod +x /usr/local/bin/restic-server
sudo restic-server --version
```

### Prepare backup directories (needs to be done only once)
I call my directories *simba* and *homebridge*:
```sh
sudo mkdir -p /home/restic-server/simba
sudo mkdir -p /home/restic-server/homebridge
sudo chown -R restic-server /home/restic-server/
```

### Create user and password for access to restic server
```sh
sudo -s
apt install apache2-utils
cd /home/restic-server
htpasswd -B -c .htpasswd simba
htpasswd -B .htpasswd homebridge
chown -R restic-server .htpasswd
chmod 600 .htpasswd
exit
```
Note that the usernames and backup directories need to have the same name.

### Create systemd service
```sh
sudo nano /etc/systemd/system/restic-server.service
```
This is the contents of the file:
```sh
[Unit]
Description=Restic Server
After=syslog.target
After=network.target

[Service]
Type=simple
User=restic-server
ExecStart=/usr/local/bin/restic-server --path /home/restic-server --private-repos --append-only
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Run restic-server using systemd
```sh
sudo systemctl daemon-reload
sudo systemctl enable restic-server
sudo systemctl start restic-server
sudo systemctl status restic-server
```

### Prepare the restic repository (ONLY DO ONCE)
Log into the server where the data to be backed up is located and create a new restic repository following the [prepare a new restic repository](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html) instructions. I use the following command (note the trailing space in front of command to not save it in the history):
```sh
 restic -r rest:http://simba:RESTPASSWORD@TAILSCALEIP:8000/simba init
 restic -r rest:http://homebridge:RESTPASSWORD@TAILSCALEIP:8000/homebridge init
```

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
