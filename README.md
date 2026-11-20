# Deployment and host configuration of my machines

Compose files, host configuration, systemd and launchd jobs, and scripts for my Raspberry Pi 4 with Home Assistant OS, my Dell Wyse 5070 with Nextcloud AIO, and my Mac mini M4 Pro with Gitea and modCraft.
My guides on [mutschler.dev](https://mutschler.dev) explain every step; they clone this repository and use the files from there.
On the Wyse and the Mac mini, the clone lives in `~/scripts`, and the compose stacks run from it.
Folders such as `etc/`, `usr/` and `Library/LaunchAgents/` mirror the target paths of their files.
The filled-in `.env` files stay out of Git ([`.gitignore`](.gitignore)).

## Raspberry Pi 4 Model B

Runs Home Assistant OS with Zigbee2MQTT on a Sonoff Zigbee 3.0 USB Dongle Plus.
It sends a daily encrypted backup to the Samba share on the Dell Wyse and pings healthchecks.io every minute.
Guide: [Home Assistant OS on a Raspberry Pi 4: clean install and restore from backup](https://mutschler.dev/linux/raspi-home-assistant-os/); [Step 8](https://mutschler.dev/linux/raspi-home-assistant-os/#step-8-restore-from-a-backup) restores it from a backup.

| File | Purpose | Guide |
|---|---|---|
| [`Raspberry-Pi-4-Model-B/flash-haos.sh`](Raspberry-Pi-4-Model-B/flash-haos.sh) | macOS: writes the current Home Assistant OS image for the Pi 4 to an SD card or USB SSD and verifies the download, the image and the written disk | [Step 1, Option B](https://mutschler.dev/linux/raspi-home-assistant-os/#option-b-terminal-on-macos) |
| [`Raspberry-Pi-4-Model-B/homeassistant/packages/healthchecks.yaml`](Raspberry-Pi-4-Model-B/homeassistant/packages/healthchecks.yaml) | Home Assistant package that pings healthchecks.io every minute; the ping URL goes into `secrets.yaml` | [Step 7](https://mutschler.dev/linux/raspi-home-assistant-os/#step-7-healthchecksio-heartbeat) |

### After a change

- `flash-haos.sh` runs from a clone on a Mac: run `git pull` there before flashing.
- `healthchecks.yaml`: paste the new content into `/homeassistant/packages/healthchecks.yaml` with Studio Code Server, check the configuration with `ha core check` and restart Home Assistant ([Step 7](https://mutschler.dev/linux/raspi-home-assistant-os/#step-7-healthchecksio-heartbeat)).

## Dell Wyse 5070 Thin Client

Runs Ubuntu Server 26.04 LTS on a LUKS-encrypted BTRFS SSD, which I unlock over SSH at boot, with Nextcloud All-in-One (AIO) in Docker behind a Tailscale sidecar.
BTRBK takes hourly snapshots and sends them daily to an encrypted USB disk (HDD 1), AIO makes a daily Borg backup to a second disk (HDD 2), and a daily job mirrors the Borg repository and the Home Assistant backups to a Hetzner Storage Box.
A Samba share collects the Home Assistant backups of the Pi, and each `dell-wyse-*` job reports to its own healthchecks.io check.
Guides: [Ubuntu Server 26.04 LTS, BTRFS and Nextcloud AIO with a Tailscale sidecar](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/) and, for the hardware, [RAM and SSD upgrade, BIOS update and BIOS settings for a home server](https://mutschler.dev/linux/wyse-hardware/).
A rebuild reuses the backup disks ([7.2.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#722-rebuilding-the-wyse-reuse-the-hdds)), restores the Borg repository and the Home Assistant backups from the Storage Box if HDD 2 is lost ([7.7](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#77-restore-from-the-storage-box)) and reinstalls Nextcloud from an AIO backup ([9.4](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#94-path-b-reinstall-from-an-aio-backup)).
What it needs from outside the Wyse is listed in [10.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#102-host-configuration-and-recovery-material).

| File | Purpose | Guide |
|---|---|---|
| [`Dell-Wyse-Thin-Client-5070/docker-compose.yml`](Dell-Wyse-Thin-Client-5070/docker-compose.yml) | Tailscale sidecar and AIO mastercontainer, compose project `dell-wyse` | [9.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#92-configure-the-deployment-on-the-wyse) |
| [`Dell-Wyse-Thin-Client-5070/dell-wyse.env`](Dell-Wyse-Thin-Client-5070/dell-wyse.env) | Template for `.env` next to the compose file: OAuth secret, node name, serve configuration and data directory | [9.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#92-configure-the-deployment-on-the-wyse) |
| [`Dell-Wyse-Thin-Client-5070/host.env.example`](Dell-Wyse-Thin-Client-5070/host.env.example) | Template for `/etc/dell-wyse/host.env`: healthchecks.io ping key and the Storage Box settings | [7](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#7-backup-disks-snapshots-alerts-and-the-home-assistant-share) |
| [`Dell-Wyse-Thin-Client-5070/etc/ssh/sshd_config.d/00-local-hardening.conf`](Dell-Wyse-Thin-Client-5070/etc/ssh/sshd_config.d/00-local-hardening.conf) | Key-only SSH; local forwarding stays on for the break-glass tunnel to the AIO interface | [5.5](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#55-key-only-ssh-verified-before-password-login-is-disabled) |
| [`Dell-Wyse-Thin-Client-5070/etc/dracut.conf.d/90-dell-wyse.conf`](Dell-Wyse-Thin-Client-5070/etc/dracut.conf.d/90-dell-wyse.conf) | Host-only initrd with networking and bash for dracut-sshd | [5.7](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#57-unlocking-the-system-disk-over-ssh) |
| [`Dell-Wyse-Thin-Client-5070/etc/systemd/system/docker.service.d/storage.conf`](Dell-Wyse-Thin-Client-5070/etc/systemd/system/docker.service.d/storage.conf), [`containerd.service.d/storage.conf`](Dell-Wyse-Thin-Client-5070/etc/systemd/system/containerd.service.d/storage.conf) | Docker and containerd start only on top of their BTRFS subvolumes | [6.1](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#61-safeguards-before-dockers-first-start) |
| [`Dell-Wyse-Thin-Client-5070/etc/docker/daemon.json`](Dell-Wyse-Thin-Client-5070/etc/docker/daemon.json) | `local` log driver | [6.1](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#61-safeguards-before-dockers-first-start) |
| [`Dell-Wyse-Thin-Client-5070/etc/btrbk/btrbk.conf`](Dell-Wyse-Thin-Client-5070/etc/btrbk/btrbk.conf) | Snapshots on the SSD and their copies on HDD 1, with retention | [7.3](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#73-hourly-snapshots-and-daily-sendreceive-with-btrbk) |
| [`Dell-Wyse-Thin-Client-5070/etc/smartd.conf`](Dell-Wyse-Thin-Client-5070/etc/smartd.conf) | SMART monitoring and self-tests of all three disks | [7.4](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#74-disk-health-monthly-scrub-and-smart-monitoring) |
| [`Dell-Wyse-Thin-Client-5070/etc/samba/smb.conf`](Dell-Wyse-Thin-Client-5070/etc/samba/smb.conf) | SMB 3 share `ha-backups` for the Home Assistant backups, open only to the Pi | [7.5](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#75-backup-share-for-home-assistant) |
| [`Dell-Wyse-Thin-Client-5070/etc/udev/rules.d/60-dell-wyse-hdd1-write-cache.rules`](Dell-Wyse-Thin-Client-5070/etc/udev/rules.d/60-dell-wyse-hdd1-write-cache.rules) | Cache flushes for HDD 1, whose USB bridge hides the drive's write cache | [7.2.3](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#723-unlock-and-mount-the-hdds-at-boot) |
| [`Dell-Wyse-Thin-Client-5070/etc/systemd/system/`](Dell-Wyse-Thin-Client-5070/etc/systemd/system/) | The `dell-wyse-*` services and timers of the snapshots, the send/receive, the off-site mirror, the scrub, the Home Assistant backup check and the uptime ping, and `dell-wyse-fail@.service` for their failure pings | [7](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#7-backup-disks-snapshots-alerts-and-the-home-assistant-share) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-hc-ping`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-hc-ping) | Success and failure pings to healthchecks.io | [7.1](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#71-alerts-to-healthchecksio) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-offsite`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-offsite) | Mirror of the Borg repository and the Home Assistant backups on the Storage Box | [7.6](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#76-off-site-mirror-on-a-hetzner-storage-box) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-ha-backup-check`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-ha-backup-check) | Fails unless Home Assistant delivered a backup within the last 26 hours | [7.5.3](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#753-checks) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-smartd-alert`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-smartd-alert) | Forwards smartd's findings to healthchecks.io instead of mail | [7.4](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#74-disk-health-monthly-scrub-and-smart-monitoring) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-btrbk-progress`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-btrbk-progress) | Progress of the running BTRBK send to HDD 1, and how much the next send will carry | [11.1](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#111-catch-up-on-missed-daily-sends) |
| [`Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-reboot-check`](Dell-Wyse-Thin-Client-5070/usr/local/sbin/dell-wyse-reboot-check) | Tells whether a reboot would interrupt a job or break the SSH unlock | [11.3](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#113-reboot-the-wyse) |

### After a change

The compose stack runs straight from the clone, while the files under `etc/` and `usr/` are copies on the host.
The loop from [10.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#102-host-configuration-and-recovery-material) compares those copies with the repository: `-` lines are the host's and `+` lines the repository's, and a file missing on the host shows up as `No such file or directory`.
No output means that every file under `etc/` and `usr/` matches its copy; files that exist only on the host do not show up.
Run it before the pull, to see changes made on the host that the repository lacks:

```sh
cd ~/scripts/Dell-Wyse-Thin-Client-5070
find etc usr -type f | while read -r f; do diff -u "/$f" "$f"; done
```

Carry such a change into the repository where you commit and push, and push it before you pull here; an edit made in the clone itself stops `git pull` as soon as the same file changes upstream.
Then pull and run the loop again; now it shows the changes from the repository that the host lacks:

```sh
git pull
find etc usr -type f | while read -r f; do diff -u "/$f" "$f"; done
```

`git pull` lists the files it changed, including those at the folder's top level, which the loop skips.
Work through them in this order ([5.3](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#53-the-scripts-repository)):

1. Templates: carry new or changed settings from `dell-wyse.env` and `host.env.example` into `.env` and, with `sudoedit`, into `/etc/dell-wyse/host.env`; their comments say which values are read only once or must never change.
2. `sudo docker compose up -d`, unless you stopped the stack on purpose: it applies changes to the compose file and `.env`, while a plain `restart` keeps the old settings ([10.6](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#106-updates)).
   A changed serve file in `Tailscale/` needs nothing more, as the sidecar re-applies it by itself ([9.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#92-configure-the-deployment-on-the-wyse)).
   A change to the `nextcloud-aio` service, such as its limits or `devices`, reaches AIO's own containers only when you stop and start them in the AIO interface ([9.5](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#95-after-either-path-nextcloud-configuration)).
3. Install every file that the loop shows, and apply it:
   - Scripts: `sudo install -m 0755 usr/local/sbin/dell-wyse-* /usr/local/sbin/`; their next run uses them.
   - Units: `sudo install -m 0644 etc/systemd/system/dell-wyse-* /etc/systemd/system/` and `sudo systemctl daemon-reload`, then check `systemctl list-timers 'dell-wyse-*'`, because a timer moved to a later time can start at once; a new timer also needs the `systemctl enable --now` line from its guide section.
   - `btrbk.conf`: check it first with `sudo btrbk -c etc/btrbk/btrbk.conf dryrun`, which lists what a run would create and delete, then `sudo install -D -m 0644 etc/btrbk/btrbk.conf /etc/btrbk/btrbk.conf`; the next hourly run applies it to the snapshots on the SSD, the next daily send at 01:30 to the copies on HDD 1.
   - `smb.conf`: check it first with `sudo testparm -s etc/samba/smb.conf`, then `sudo install -D -m 0644 etc/samba/smb.conf /etc/samba/smb.conf` and `sudo systemctl restart smbd`, but not while Home Assistant uploads its backup (04:45 to 05:45).
   - `smartd.conf`: `sudo install -D -m 0644 etc/smartd.conf /etc/smartd.conf` and `sudo systemctl restart smartmontools.service`, then check with `sudo journalctl -u smartmontools.service -b --no-pager` that it found all three disks.
   - `00-local-hardening.conf`: `sudo install -D -m 0644 etc/ssh/sshd_config.d/00-local-hardening.conf /etc/ssh/sshd_config.d/00-local-hardening.conf` and `sudo sshd -t && sudo systemctl reload ssh`; keep the current session open and log in from a second terminal before you close it.
   - `90-dell-wyse.conf`: `sudo install -D -m 0644 etc/dracut.conf.d/90-dell-wyse.conf /etc/dracut.conf.d/90-dell-wyse.conf` and `sudo update-initramfs -u -k all`, then run `dell-wyse-reboot-check` before the next reboot.
   - The udev rule: `sudo install -m 0644 etc/udev/rules.d/60-dell-wyse-hdd1-write-cache.rules /etc/udev/rules.d/`, `sudo udevadm control --reload` and `sudo udevadm trigger --action=add --settle --subsystem-match=scsi_disk`; HDD 1's LUKS mapping takes the setting over when it is next opened, at the latest at the next boot.
   - `daemon.json` and the two `storage.conf` drop-ins: check `daemon.json` first with `sudo dockerd --validate --config-file=etc/docker/daemon.json`, then run their `install` lines from [6.1](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#61-safeguards-before-dockers-first-start) and `sudo systemctl daemon-reload`; Docker and containerd use them from their next start on, at the next reboot or Docker package upgrade, and a changed log driver only reaches containers created afterwards.
4. A file that the pull deleted or renamed (`delete mode` or `=>` in its summary) stays on the host: stop a removed timer with `sudo systemctl disable --now NAME.timer`, delete the old copies and run `sudo systemctl daemon-reload`.

## Apple Mac mini M4 Pro

My research workstation.
In OrbStack it also runs Gitea with PostgreSQL and a Gitea Actions runner behind a Tailscale sidecar that only my tailnet can reach, and modCraft, from its own repository, behind a second sidecar with Funnel until modCraft moves to a VPS of its own.
A daily Gitea backup lands in `~/Backups/gitea`, which Time Machine copies to an external SSD, and an uptime check runs every five minutes; both report to healthchecks.io.
Guide: [Gitea with Actions CI and modCraft in OrbStack behind Tailscale sidecars](https://mutschler.dev/apple/mac-mini-gitea-modcraft/); restoring Gitea from a backup is part of the [restore drills](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#104-restore-drills), and [10.5](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#105-recovery-material) lists the recovery material.

| File | Purpose | Guide |
|---|---|---|
| [`Apple-Mac-mini-M4-Pro/docker-compose.yml`](Apple-Mac-mini-M4-Pro/docker-compose.yml) | Gitea, PostgreSQL, the container runner and the sidecars of Gitea and modCraft, compose project `mac-mini` | [5](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#5-configure-the-deployment) |
| [`Apple-Mac-mini-M4-Pro/mac-mini.env`](Apple-Mac-mini-M4-Pro/mac-mini.env) | Template for `.env` next to the compose file: OAuth secret, node names, Gitea's domain and secrets, runner token, modCraft's serve configuration | [5](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#5-configure-the-deployment) |
| [`Apple-Mac-mini-M4-Pro/gitea-runner.yaml`](Apple-Mac-mini-M4-Pro/gitea-runner.yaml) | The container runner: labels, cache, jobs on the network `gitea-ci` without a Docker socket | [8](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#8-gitea-actions-on-the-mac-mini) |
| [`Apple-Mac-mini-M4-Pro/gitea-runner-host.yaml`](Apple-Mac-mini-M4-Pro/gitea-runner-host.yaml) | The optional runner directly on macOS (label `macos-arm64`), copied to `~/.config/gitea-runner/config.yaml` | [8.4](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#84-optional-a-runner-directly-on-macos) |
| [`Apple-Mac-mini-M4-Pro/host.env.example`](Apple-Mac-mini-M4-Pro/host.env.example) | Template for `~/.config/mac-mini/host.env`: healthchecks.io ping key, backup folder and how many runs it keeps, and how the uptime check reaches modCraft | [10.1](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#101-healthchecksio-and-the-hosts-settings) |
| [`Apple-Mac-mini-M4-Pro/gitea-mirror`](Apple-Mac-mini-M4-Pro/gitea-mirror) | Creates pull mirrors of all repositories of a GitHub user or organization, or a GitLab user or group; skips what exists | [7.3](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#73-mirror-everything-with-gitea-mirror) |
| [`Apple-Mac-mini-M4-Pro/mac-mini-gitea-backup`](Apple-Mac-mini-M4-Pro/mac-mini-gitea-backup) | Daily backup: stops Gitea briefly, `pg_dump` plus `gitea dump` into `~/Backups/gitea` | [10.3](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#103-what-the-backup-contains) |
| [`Apple-Mac-mini-M4-Pro/mac-mini-gitea-restore`](Apple-Mac-mini-M4-Pro/mac-mini-gitea-restore) | Restores such a backup into a fresh installation; refuses to overwrite data or to run with another `SECRET_KEY` | [10.4](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#104-restore-drills) |
| [`Apple-Mac-mini-M4-Pro/mac-mini-alive`](Apple-Mac-mini-M4-Pro/mac-mini-alive) | Uptime check of Gitea through the tailnet and, optionally, of modCraft; starts OrbStack if it stopped | [10.1](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#101-healthchecksio-and-the-hosts-settings) |
| [`Apple-Mac-mini-M4-Pro/mac-mini-hc-ping`](Apple-Mac-mini-M4-Pro/mac-mini-hc-ping) | Start, success and failure pings to healthchecks.io | [10.1](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#101-healthchecksio-and-the-hosts-settings) |
| [`Apple-Mac-mini-M4-Pro/Library/LaunchAgents/`](Apple-Mac-mini-M4-Pro/Library/LaunchAgents/) | The launchd jobs `local.mac-mini-gitea-backup`, `local.mac-mini-alive` and the optional `local.mac-mini-gitea-runner` | [10.2](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#102-install-the-launchd-jobs), [8.4](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#84-optional-a-runner-directly-on-macos) |

### After a change

The compose stack and the scripts run straight from the clone, also when launchd starts them; only the plists and the optional runner's configuration are copies ([10.6](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#106-updates)).
Pick a moment when the nightly backup is not running (no `/tmp/mac-mini-gitea-backup.lock`) and no CI job is busy:

```sh
cd ~/scripts && git pull && cd Apple-Mac-mini-M4-Pro
```

`git pull` lists the files it changed; work through them in this order:

1. Templates: carry new or changed settings from `mac-mini.env` and `host.env.example` into `.env` and `~/.config/mac-mini/host.env`; their comments say which values are read only once or must never change.
2. If the pull changed `docker-compose.yml`, look at the change with `git diff ORIG_HEAD HEAD -- docker-compose.yml`.
   If it changes the image tag of `gitea`, run `./mac-mini-gitea-backup` first and continue only after `backup complete`; a new major version of `gitea-db` needs the dump and restore from [10.6](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#106-updates) before the next step.
3. `docker compose up -d`, unless you stopped a service on purpose: it applies changes to the compose file and `.env`.
   If it recreated `modcraft-tailscale`, check `docker logs modcraft-tailscale 2>&1 | grep 'disabled logging'` ([9.4](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#94-updates)).
4. Then, depending on what changed:
   - A serve file in `Tailscale/`: restart its sidecar, `docker compose restart gitea-tailscale` for `gitea-serve.json` or `docker compose restart modcraft-tailscale` for the file named in `MODCRAFT_SERVE_CONFIG`; the `nextcloud-*.json` files need nothing here.
   - `gitea-runner.yaml`: `docker compose up -d --force-recreate gitea-runner`.
   - Scripts: nothing to do.
   - A plist: compare it, e.g. `diff -u ~/Library/LaunchAgents/local.mac-mini-alive.plist Library/LaunchAgents/local.mac-mini-alive.plist`, copy it with `cp Library/LaunchAgents/local.mac-mini-alive.plist ~/Library/LaunchAgents/`, then reload it with `launchctl bootout gui/$(id -u)/local.mac-mini-alive` and `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.mac-mini-alive.plist`.
   - `gitea-runner-host.yaml`, if the optional runner is in use: compare it with `~/.config/gitea-runner/config.yaml`, copy it there, and restart the runner with `launchctl kickstart -k gui/$(id -u)/local.mac-mini-gitea-runner`.
   - A deleted or renamed plist: `launchctl bootout` its old label and delete the old copy from `~/Library/LaunchAgents/`.

## HP Elite Tower 800 G9

Planned as my next main server; no files yet.

## Tailscale

The three sidecars, one on the Wyse and two on the Mac mini, mount [`Tailscale/`](Tailscale/) read-only and load their serve configuration from it.
All three set `TS_NO_LOGS_NO_SUPPORT=true`, so tailscaled uploads no client logs to Tailscale.
The price is that Tailscale support cannot look at the logs of these nodes; modCraft's privacy policy relies on the setting.

| File | Purpose | Guide |
|---|---|---|
| [`Tailscale/nextcloud-funnel.json`](Tailscale/nextcloud-funnel.json) | Nextcloud on HTTPS 443, published through Funnel, and the AIO interface on 8080, tailnet only; the compose file's default | [Wyse 9.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#92-configure-the-deployment-on-the-wyse) |
| [`Tailscale/nextcloud-serve.json`](Tailscale/nextcloud-serve.json) | The same without Funnel, for a Nextcloud that only the tailnet can reach | [Wyse 9.2](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#92-configure-the-deployment-on-the-wyse) |
| [`Tailscale/gitea-serve.json`](Tailscale/gitea-serve.json) | Gitea on HTTPS 443 and Git over SSH on 22, tailnet only | [Mac 5](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#5-configure-the-deployment) |
| [`Tailscale/modcraft-funnel.json`](Tailscale/modcraft-funnel.json) | modCraft on HTTPS 443, published through Funnel; the compose file's default | [Mac 9.2](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#92-build-and-start-modcraft-and-its-sidecar) |
| [`Tailscale/modcraft-serve.json`](Tailscale/modcraft-serve.json) | The same without Funnel, for a modCraft that only the tailnet can reach | [Mac 9.5](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#95-serve-instead-of-funnel) |

## Calendar

My restore drills and regular maintenance as recurring all-day events, each with a reminder at 09:00, a checklist with the passing result of every drill, and links to the guide sections.
Overview: [My backup strategy](https://mutschler.dev/stuff/backup/).

| File | Purpose | Guide |
|---|---|---|
| [`Calendar/backup-drills-and-maintenance.ics`](Calendar/backup-drills-and-maintenance.ics) | Monthly checks (2nd Saturday); quarterly restore drills for the Wyse and Home Assistant (1st Saturday of March, June, September and December) and for Gitea (3rd Saturday), quarterly updates (last Saturday); yearly drills for the Wyse and Home Assistant (January) and the Mac mini (July) | [Wyse 10.4 to 10.6](https://mutschler.dev/linux/wyse-ubuntu-nextcloud-aio/#105-restore-drills), [Mac 10.4 to 10.7](https://mutschler.dev/apple/mac-mini-gitea-modcraft/#104-restore-drills) |

### After a change

- Import the file once: in Calendar on the Mac, **File → Import**, and pick a calendar of its own, e.g. "Backups", so that a later version can replace it by deleting that calendar and importing again.
- On the iPhone, the events arrive through iCloud if that calendar is an iCloud calendar.

## Files of older guides

Some older posts on mutschler.dev, such as [My backup strategy (2022)](https://mutschler.dev/stuff/backup_old/) and the post-installation guides for Ubuntu, Pop!_OS and Debian, refer to files that are no longer here, for example the Docker Compose and BTRBK files of my former Lenovo server and my restic and BTRFS maintenance scripts.
They remain in the [Git history](https://github.com/wmutschl/scripts/commits/main/).
