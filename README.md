# Backup and Installation Scripts
These are the scripts I use for my [backup strategy](https://mutschler.eu/linux/backup) and my [installation guides](https://mutschler.eu/linux/install-guides).

## .env files
Copy the machine specific env file on the required machine to `.env`.

## Crontab
You can overwrite the current crontab with the machine specific one:
```sh
sudo crontab xyz-crontab.txt
```
Note to adjust the healthchecks.io ping address.

## Systemd timers for btrbk on Precision laptop (WIP)
First install btrbk
```sh
git clone https://github.com/digint/btrbk.git
cd btrbk
sudo make install
```

Then let's copy our script
```
sudo cp /home/wmutschl/scripts/btrfs-btrbk.sh /usr/bin/btrfs-btrbk.sh
sudo chmod --reference /usr/bin/btrbk /usr/bin/btrfs-btrbk.sudo nano /lib/systemd/system/btrbk.service
```
The systemd service:
```
# [Unit]
# Description=btrbk backup
# Documentation=man:btrbk(1)

# [Service]
# Type=oneshot
# ExecStart=/usr/bin/btrfs-btrbk.sh
```

the systemd timer
```
# [Unit]
# Description=btrbk hourly backup
# 
# [Timer]
# OnCalendar=hourly
# AccuracySec=10min
# Persistent=true
# 
# [Install]
# WantedBy=timers.target
```

Now enable, start and reload:
```
sudo systemctl start btrbk.service #check if error
sudo systemctl enable btrbk.timer
sudo systemctl start btrbk.timer
sudo systemctl daemon-reload

sudo systemctl list-timers --all
#NEXT                         LEFT          LAST                         PASSED     UNIT                         ACTIVATES                     
#Thu 2021-05-20 11:00:00 CEST 29min left    Thu 2021-05-20 10:09:19 CEST 20min ago  btrbk.timer                  btrbk.service
```
