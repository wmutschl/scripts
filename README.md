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

## Nextcloud All-in-One (AIO) on macOS using Tailscale serve as sidecar
This setup uses the official Nextcloud All-in-One (AIO) image to create a secure and fully-managed Nextcloud instance:

1. **Nextcloud AIO mastercontainer**: Manages the entire Nextcloud stack and required services.

2. **Tailscale sidecar container**: Provides secure access without exposing ports to your local network

**Key Benefits:**
- All-in-one solution with automatic updates
- Built-in backup and restore capabilities
- Optimized performance out-of-the-box
- No manual database or Redis configuration needed
- Secure by default (no ports exposed to local network)

For secure access, we use Tailscale serve to restrict access to only authorized machines on your tailnet.
Your tailnet name (e.g., `hippocampus-rockhopper`) can be found in the Tailscale Admin panel under DNS settings.

Once configured, your Nextcloud will be accessible at `https://<hostname>.hippocampus-rockhopper.ts.net` with automatic SSL certificate management via Tailscale HTTPS.
For public internet access, you can enable Tailscale funnel by setting `AllowFunnel` to `true` in `tailscale-config/tailscale-nextcloud.json` (not recommended for security reasons).

### Tailscale setup
Go to the Tailscale Admin Panel and under DNS make note of your tailnet name. Also make sure MagicDNS is enabled.

Then go to `Access controls` and make sure you have a tag for containers under `tagOwners`, e.g. `tag:container` (this is required for the tailscale sidecar to work):
```sh
	// Define the tags which can be applied to devices and by which users.
	"tagOwners": {
		"tag:container": ["autogroup:admin"],
	},
```

Next, go to Settings and OAuth clients to `Generate OAuth client` with the following scopes:
- Devices - Core: Read and Write (add `tag:container` under Tags)
- Keys - OAuth Keys: Read and Write
The `Client secret` is the `TAILSCALE_OAUTH_KEY` key you need to add to the `.env` file (below).

### Orbstack setup
Orbstack is a lightweight alternative to Docker Desktop, so I use it and install it via brew:
```sh
brew install orbstack
```
Run it, install the helper and go through the wizard (What do you want to use? -> Docker).
Change the settings to your needs, for me I enable `Start at login` and `Automatically download updates`.

### Docker compose setup
Make sure you work in the `scripts` directory:
```sh
cd $HOME/scripts
```
Copy the `mac.env` file to `.env` and add values for:
- `TAILSCALE_OAUTH_KEY`: Your OAuth client secret from Tailscale (see above)
- `TAILSCALE_HOSTNAME`: The hostname for your Nextcloud (e.g., `cloud` will become `cloud.hippocampus-rockhopper.ts.net`)
- `HOME`: Your home directory path (e.g., `/Users/wmutschl`) - for custom data directory

```sh
cp mac.env .env
nano .env
```

Review the docker compose file and tailscale config:
```sh
nano mac-docker-compose.yml
nano tailscale-config/tailscale-nextcloud.json
```

**Security options in `tailscale-nextcloud.json`:**
- `AllowFunnel`: Set to `false` for Tailscale-only access (recommended for security)
- Port `8080`: Admin interface access (for initial setup and management)
- Port `443`: Main Nextcloud access (after setup is complete)

Run the containers:
```sh
docker compose -f mac-docker-compose.yml up -d

# Monitor the logs to ensure everything starts correctly
docker compose -f mac-docker-compose.yml logs -f
```

### Initial setup via web interface

**Step 1: Access the AIO admin interface**

Open your browser and navigate to (replace `cloud` with your chosen hostname):
```
https://cloud.hippocampus-rockhopper.ts.net:8080
```

**Important:** You must use port `:8080` for the initial setup!

**Step 2: Copy the initial password**

You'll see the AIO interface with an automatically generated password displayed. Copy this password - you'll need it immediately.

**Step 3: Enter the password and configure**

1. Paste the password when prompted
2. Enter your domain: `cloud.hippocampus-rockhopper.ts.net` (without the `:8080` port!)
3. Select timezone and location
4. Choose which optional containers to install

**Step 4: Start installation**

Click "Start containers" and wait 5-10 minutes for the installation to complete. The process will:
- Download all required Docker images
- Set up PostgreSQL database
- Configure Redis cache
- Set up Apache web server
- Generate SSL certificates
- Initialize Nextcloud

**Step 5: Access your Nextcloud**

Once complete, access your Nextcloud at:
```
https://cloud.hippocampus-rockhopper.ts.net
```

The initial admin username will be shown in the AIO interface along with the password.

### Post-installation

**Backup configuration:**
- AIO includes built-in backup using BorgBackup
- Configure backups in the AIO interface at `https://cloud.hippocampus-rockhopper.ts.net:8080`
- Recommended: Set up automated daily backups

**Security hardening:**
- ✅ No ports exposed to local network (Tailscale-only access)
- ✅ Jumbo frames enabled for better container-to-container performance
- ✅ Automatic HTTPS via Tailscale certificates
- ✅ Regular security updates via AIO's built-in update mechanism

**Monitoring:**
Check container status:
```sh
docker compose -f mac-docker-compose.yml ps
docker compose -f mac-docker-compose.yml logs -f
```

**Troubleshooting:**
- If you can't access the interface, ensure you're connected to Tailscale
- Check logs: `docker compose -f mac-docker-compose.yml logs nextcloud-tailscale`
- Verify Tailscale hostname: `docker exec nextcloud-tailscale tailscale status`
- For full documentation: https://github.com/nextcloud/all-in-one

### Post-installation tasks

After the initial setup, perform these maintenance and configuration tasks:

**1. Remove MIME type warning:**
```sh
docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive
```

**2. Set default phone region:**
```sh
docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set default_phone_region --value="DE"
```

**3. Enable Full Text Search with Elasticsearch** (if the fulltextsearch container is enabled):

Allow "untested app" in the Nextcloud web UI for the three fulltextsearch apps (Settings → Apps → search for each app).

Then enable and configure the apps:
```sh
# Enable apps
docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable fulltextsearch
docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable fulltextsearch_elasticsearch
docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable files_fulltextsearch

# Configure Elasticsearch
docker exec --user www-data nextcloud-aio-nextcloud php occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}'
docker exec --user www-data nextcloud-aio-nextcloud php occ config:app:set fulltextsearch_elasticsearch elastic_host --value="http://nextcloud-aio-fulltextsearch:9200"
docker exec --user www-data nextcloud-aio-nextcloud php occ config:app:set fulltextsearch_elasticsearch elastic_index --value="nextcloud"

# Test the configuration
docker exec --user www-data nextcloud-aio-nextcloud php occ fulltextsearch:test

# Index all files (this may take a while)
docker exec --user www-data nextcloud-aio-nextcloud php occ fulltextsearch:index
```

New files will be automatically indexed via Nextcloud's background jobs.

**4. Clear Nextcloud logs (optional):**
```sh
# Inside the Nextcloud container, or from macOS if datadir is accessible
docker exec --user www-data nextcloud-aio-nextcloud truncate -s 0 /var/www/html/data/nextcloud.log
```

## Minecraft Server (Java Edition) on macOS

Vanilla server based on [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server),
reachable both from the LAN and from the tailnet.

Three containers make it up:

| Container | Purpose |
| --- | --- |
| `minecraft-tailscale` | Owns the network namespace. Publishes `25565` to the LAN and forwards the same port from the tailnet. |
| `minecraft` | The server itself. |
| `minecraft-backup` | Daily world snapshots, pruned after 14 days. |

`minecraft` and `minecraft-backup` join the sidecar's namespace via
`network_mode: service:minecraft-tailscale`, so they reach each other over
`127.0.0.1`. Only 25565 is published to the LAN, so RCON (25575) is not
reachable from the local network.

### RCON exposure on the tailnet

RCON *is* reachable from the tailnet, at `<tailscale-ip>:25575`. The sidecar
runs in Tailscale userspace mode, and in that mode tailscaled forwards **any**
inbound tailnet port to localhost inside the namespace - it is not limited to
the ports listed in `tailscale-config/tailscale-minecraft.json`. The serve
config gives a clean MagicDNS endpoint; it is not a filter. Kernel mode
(`/dev/net/tun` + `NET_ADMIN`) behaves the same way, and `--shields-up` is not
a workaround because it blocks Serve along with everything else.

Anyone on the tailnet who reaches RCON still needs `MINECRAFT_RCON_PASSWORD`,
which is why that must be a strong random value. To close it off properly,
scope it in the tailnet policy file, e.g.:

```json
{
  "action": "accept",
  "src":    ["*"],
  "dst":    ["tag:container:25565"]
}
```

That only takes effect once the broad default `"dst": ["*:*"]` rule is removed,
which affects every tagged container on the tailnet - including Nextcloud - so
review the whole policy before changing it.

### Setup

**1. Add the Minecraft variables to your `.env`** (copy the block from `mac.env`)
and set at least `MINECRAFT_RCON_PASSWORD`, `MINECRAFT_OPS` and
`MINECRAFT_WHITELIST`:

```sh
openssl rand -base64 24
```

Leaving `MINECRAFT_WHITELIST` empty disables the whitelist and lets anyone on the
LAN or tailnet join.

**2. Create the data directories:**

```sh
mkdir -p /Volumes/Docker/minecraft/data /Volumes/Docker/minecraft/backups
```

**3. Start it:**

```sh
docker compose -f mac-docker-compose.yml up -d minecraft-tailscale minecraft minecraft-backup
```

The first start downloads the server jar and generates the world, which takes a
few minutes. Follow along with:

```sh
docker compose -f mac-docker-compose.yml logs -f minecraft
```

**4. Approve the machine** in the Tailscale admin console if your tailnet
requires it, the same way as for `nextcloud`.

### Connecting

There is no web interface - a Minecraft server speaks its own TCP protocol, not
HTTP, so opening `https://minecraft.hippocampus-rockhopper.ts.net` in a browser
just hangs. Connect from the game instead, via *Multiplayer -> Add Server*:

- LAN: `192.168.178.65` (the `IP` from `.env`)
- Tailnet: `minecraft.hippocampus-rockhopper.ts.net`

No `https://` prefix and no `:25565` suffix - the default port is implied. A
dedicated server never appears by itself in the client's LAN list, which only
discovers single-player worlds shared with *Open to LAN*, so it has to be added
by address once.

The client version has to match the server exactly. Check what is running with:

```sh
docker exec minecraft rcon-cli version
```

Both use the default port, so no `:25565` suffix is needed in the client.

### Operating

```sh
# Server console (Ctrl-p Ctrl-q to detach without stopping the server)
docker attach minecraft

# Or run single commands over RCON
docker exec minecraft rcon-cli list
docker exec minecraft rcon-cli whitelist list
docker exec minecraft rcon-cli save-all

# Trigger a backup immediately instead of waiting for the interval
docker exec minecraft-backup backup now

# Graceful stop (players get a 20s warning, chunks are flushed)
docker compose -f mac-docker-compose.yml stop minecraft
```

Settings under `environment:` in `mac-docker-compose.yml` overwrite
`server.properties` on every start, so change them there rather than in the file.

### Ops and whitelist

`MINECRAFT_OPS` and `MINECRAFT_WHITELIST` in `.env` seed `ops.json` and
`whitelist.json`. To change either list, edit `.env` and recreate the container:

```sh
docker compose -f mac-docker-compose.yml up -d minecraft
```

`docker compose restart` is not enough - it reuses the old environment.

`EXISTING_WHITELIST_FILE` is set to `MERGE`, so players added in-game with
`/whitelist add` survive a restart. The trade-off is that removals must also
happen in-game (`/whitelist remove`) - deleting a name from
`MINECRAFT_WHITELIST` alone does not revoke access, because `MERGE` only ever
adds. Switch it to `SYNCHRONIZE` if you want `.env` to be the sole source of
truth.

### Updating

`MINECRAFT_VERSION=LATEST` pulls the newest release on every restart, which can
lock out players still on an older client. Pin it (e.g. `26.1`) if that matters.

If you pin an older version, check the Java requirement too. The server refuses
to start with `UnsupportedClassVersionError` when the image's JRE is older than
the jar - class file version 69 means Java 25, 65 means Java 21. Switch the
image tag (`itzg/minecraft-server:java25` / `:java21`) to match.

### Running a snapshot

Set `MINECRAFT_VERSION` to a snapshot id and give it its own world, so the
release world is left alone and you can switch back:

```sh
MINECRAFT_VERSION=26.3-snapshot-5
MINECRAFT_LEVEL=world-26.3-snapshot
```

List the current ids, and check which Java a given one needs, with:

```sh
curl -s https://launchermeta.mojang.com/mc/game/version_manifest_v2.json | jq '.latest'
```

Players need a matching installation in the Minecraft Launcher: *Installations
-> New installation*, then tick **snapshots** in the version dropdown and pick
the same id.

Going back to the release is just the two variables again (`LATEST` and
`world`) followed by `up -d minecraft`. Worlds are upgraded in place and never
downgraded, which is why each version gets its own `MINECRAFT_LEVEL`.

```sh
docker compose -f mac-docker-compose.yml pull minecraft
docker compose -f mac-docker-compose.yml up -d minecraft
```
