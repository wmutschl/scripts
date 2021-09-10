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
