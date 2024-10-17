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

