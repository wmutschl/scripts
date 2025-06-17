# Backup and Installation Scripts
These are the scripts I use for my [backup strategy](https://mutschler.eu/linux/backup) and my [installation guides](https://mutschler.eu/linux/install-guides).

## .env files
Copy the machine specific env file and name it `.env`.

## Crontab
You can overwrite the current crontab with the machine specific one, but remember to adjust the healthchecks.io ping address manually.
Depending on the machine, you might have to use sudo:
```sh
sudo crontab xyz-crontab.txt
sudo crontab -e
```
On macOS, you might want to use nano to edit the crontab:
```sh
crontab xyz-crontab.txt
export EDITOR=nano
crontab -e
```

## Container settings

### Swag container
After starting the [SWAG container](https://docs.linuxserver.io/general/swag), change the security settings in the `$HOME/docker/swag/nginx/ssl.conf` file. That is, enable HSTS and uncomment all optional headers for additional security, see this [post for more information](https://discourse.linuxserver.io/t/further-discussion-on-optional-swag-headers/3367).

### Gitea settings
My settings are given in the `gitea.app.ini` file. This needs to be renamed to app.ini and moved into the gitea directory.

## Update firmware of Sonoff ZigBee Stick
Check whether the current coordinator firmware of the stick  (zStack3x0) on the Zigbee2MQTT dashboard (for me port 8080): http://192.168.178.50:8080 under Settings - About. Check the `Coordinator-Version`, e.g. 20230507. Compare this with the latest version on [Koenkk/Z-Stack-firmware](https://github.com/Koenkk/Z-Stack-firmware/blob/master/coordinator/Z-Stack_3.x.0/CHANGELOG.md).
If the firmware is outdated, SSH into the machine, install dependencies and clone repositories:
```sh
sudo apt install python3-pip python3-venv git

git clone https://github.com/Koenkk/Z-Stack-firmware
git clone https://github.com/JelmerT/cc2538-bsl.git

cd cc2538-bsl
cp $HOME/Z-Stack-firmware/coordinator/Z-Stack_3.x.0/bin/CC1352P2_CC2652P_launchpad_coordinator_20240710.zip CC1352P2_CC2652P_launchpad_coordinator_20240710.zip
unzip CC1352P2_CC2652P_launchpad_coordinator_20240710.zip
rm CC1352P2_CC2652P_launchpad_coordinator_20240710.zip

bash # make sure you are in bash and not in fish
python3 -m venv sonoff
source sonoff/bin/activate
pip install wheel pyserial intelhex python-magic
pip install .
```

Shut down the process that uses the stick, e.g. Zigbee2MQTT, and find out the port:
```sh
docker compose -f $HOME/scripts/thinclient-docker-compose.yml down

ls -la /dev/serial/by-id/
# lrwxrwxrwx 1 root root 13 Oct 17 08:36 usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0 -> ../../ttyUSB0
```

Flash the firmware:
```sh
sudo python3 cc2538-bsl.py -p /dev/ttyUSB0 -e -v -w --bootloader-sonoff-usb CC1352P2_CC2652P_launchpad_coordinator_20240710.hex

deactivate
```

Restart the process that uses the stick, e.g. Zigbee2MQTT:
```sh
docker compose -f $HOME/scripts/thinclient-docker-compose.yml up -d
```

## Nextcloud container on macOS using Tailscale serve as sidecar
The goal is to use the Nextcloud container provided by linuxserver.io, combine it with their mariadb container for the database and use the official redis container to optimize the Nextcloud. Moreover, I want my Nextcloud to be reachable over the internet, but in a protected way. Thus, I am going to use Tailscale serve to put the Nextcloud behind tailscale, such that it is only accessible by machines on my tailnet.
Note that my tailnet name is `hippocampus-rockhopper` (check yours or create it in the Admin panel under DNS).
That is, the Nextcloud should be reachable via `https://nextcloud.hippocampus-rockhopper.ts.net` with a valid SSL certificate and only for the machines on my tailnet. One can even make the Nextcloud accessible over the Internet by everyone (with a valid SSL certificate) using Tailscale funnel, for this you have to set `AllowFunnel` in `tailscale-config/tailscale-nextcloud.json` to `true`.
The other steps are the same.

### Tailscale setup
Go to the Tailscale Admin Panel and under DNS make note of your tailnet name. Also make sure MagicDNS is enabled.

Then go to `Access control` and make sure you have a tag for containers under `tagOwners`, e.g. `tag:container` (this is required for the tailscale sidecar to work):
```sh
	// Define the tags which can be applied to devices and by which users.
	"tagOwners": {
		"tag:container": ["autogroup:admin"],
	},
```

Next, go to Settings and OAuth clients to `Generate OAuth client` with the following scopes:
- Devices - Core: Read and Write (add `tag:container` under Tags)
- Keys - OAuth Keys: Read and Write (add `tag:container` under Tags)

### Orbstack setup
Orbstack is a lightweight alternative to Docker Desktop, so I use it and install it via brew:
```sh
brew install orbstack
```
Run it and check the settings (there is a menu button in the top right corner).

### Docker compose setup
Make sure you work in the `scripts` directory:
```sh
cd $HOME/scripts
```
Copy the `mac.env` file to `.env` and add values for the passwords and the Tailscale OAuth key:
```sh
cp mac.env .env
nano .env
```
Check out the docker compose file and the tailscale config file:
```sh
nano mac-docker-compose.yml
nano taiscale-config/tailscale-nextcloud.json
```
Run the containers:
```sh
docker compose -f mac-docker-compose.yml up -d
```

### Initial setup
Go to the ip address of your server (e.g. 192.168.178.65) and:
- set the administrator password
- change the database type to MySQL/MariaDB
- use the information you provided in the .env file to:
  - set the database user name (`NEXTCLOUD_MARIADB_USER`), database password (`NEXTCLOUD_MARIADB_PASSWORD`), database name (`NEXTCLOUD_MARIADB_DATABASE`) and database host (`NEXTCLOUD_MARIADB_HOST`).
  - set the redis password (`NEXTCLOUD_REDIS_PASSWORD`).
- set the letsencrypt email (`LETSENCRYPT_EMAIL`) and domain (`LETSENCRYPT_DOMAIN`).
- set the subdomains (`LETSENCRYPT_SUBDOMAINS`).
- set the extra domains (`LETSENCRYPT_EXTRA_DOMAINS`).

### Optimize Nextcloud
Restart the container, make note of the **Security & setup warnings** in the *Administration Settings* and check the logs:
```sh
docker compose -f mac-docker-compose.yml down
docker compose -f mac-docker-compose.yml up -d
docker compose -f mac-docker-compose.yml logs -f nextcloud-redis
docker compose -f mac-docker-compose.yml logs -f nextcloud-mariadb
docker compose -f mac-docker-compose.yml logs -f nextcloud
```
Stop the container and open the `config.php` file:
```sh
docker compose -f mac-docker-compose.yml down
nano /Volumes/Docker/nexcloud/config/www/nextcloud/config/config.php`
```
Replace `'memcache.locking' => '\\OC\\Memcache\\APCu'` with the following lines to make redis the default cache:
<?php
$CONFIG = array (
  ...
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'filelocking.enabled' => true,
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => 
  array (
    'host' => 'nextcloud-redis',
    'password' => 'NEXTCLOUD_REDIS_PASSWORD (from .env)',
    'port' => 6379,
  ),
  ...
);
```
Restart the container and check the logs again:
```sh
docker compose -f mac-mini-docker-compose.yml up -d

docker compose -f mac-mini-docker-compose.yml logs -f nextcloud-redis # close with CTRL+C
# nextcloud-redis  | 1:M 27 May 2025 06:47:23.780 * DB loaded from disk: 0.001 seconds
# nextcloud-redis  | 1:M 27 May 2025 06:47:23.780 * Ready to accept connections tcp

docker compose -f mac-mini-docker-compose.yml logs -f nextcloud-mariadb # close with CTRL+C
# nextcloud-mariadb  | [custom-init] No custom files found, skipping...
# nextcloud-mariadb  | 250527 08:47:23 mysqld_safe Logging to '/config/log/mysql/mariadb-error.log'.
# nextcloud-mariadb  | 250527 08:47:23 mysqld_safe Starting mariadbd daemon with databases from /config/databases
# nextcloud-mariadb  | Connection to localhost (::1) 3306 port [tcp/mysql] succeeded!
# nextcloud-mariadb  | Logrotate is enabled
# nextcloud-mariadb  | [ls.io-init] done.

docker compose -f mac-mini-docker-compose.yml logs -f nextcloud # close with CTRL+C
# nextcloud  | using keys found in /config/keys
# nextcloud  | [custom-init] No custom files found, skipping...
# nextcloud  | **** Making sure the Nextcloud Client Push plugin is installed and enabled ****
# nextcloud  | notify_push 1.1.0 installed
# nextcloud  | notify_push enabled
# nextcloud  | notify_push already enabled
# nextcloud  | **** Adding notify_push (127.0.0.1) to trusted proxies ****
# nextcloud  | System config value trusted_proxies => 0 set to string 127.0.0.1
# nextcloud  | **** Adding notify_push (::1) to trusted proxies ****
# nextcloud  | System config value trusted_proxies => 1 set to string ::1
# nextcloud  | **** Starting notify-push ****
# nextcloud  | Connection to localhost (127.0.0.1) 7867 port [tcp/*] succeeded!
# nextcloud  | **** Setting notify_push server URL to http://192.168.178.65/push ****
# nextcloud  | ✓ redis is configured
# nextcloud  | 🗴 using unencrypted http for push server is strongly discouraged
# nextcloud  | ✓ push server is receiving redis messages
# nextcloud  | ✓ push server can load mount info from database
# nextcloud  | ✓ push server can connect to the Nextcloud server
# nextcloud  | ✓ push server is a trusted proxy
# nextcloud  | ✓ push server is running the same version as the app
# nextcloud  |   configuration saved
# nextcloud  | [ls.io-init] done.
```