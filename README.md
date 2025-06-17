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
My settings are given in the gitea.app.ini file. This needs to be renamed to app.ini and moved into the gitea directory.

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