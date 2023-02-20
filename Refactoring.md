# Refactoring

Menu template

```
<details><summary><code></code></summary>

</details>
```

- [x] Install functions
- [x] Test functions
- [ ] Docker functions
- [ ] Clean up code

### Project

`×` = Ongoing

- [x] = Done

<details><summary><code>/</code></summary>

- [x] /install.sh
- [x] /lamp.sh
- [x] /ncp.sh
- [x] /post-inst.sh
- [x] /update.sh
- [ ] /run_update_history.sh
- [ ] /tag_and_push.sh

</details>

<details><summary><code>/bin</code></summary>

- [ ] /ncp-backup `×`
- [ ] /ncp-check-nc-version `×`
- [ ] /ncp-check-updates
- [ ] /ncp-check-version
- [ ] /ncp-config
- [ ] /ncp-diag
- [ ] /ncp-dist-upgrade
- [ ] /ncp-provisioning.sh
- [ ] /ncp-report
- [ ] /ncp-restore
- [ ] /ncp-suggestions
- [ ] /ncp-test-updates
- [x] /ncp-update
- [x] /ncp-update-nc
- [ ] /nextcloud-domain.sh `×`

</details>

<details><summary><code>/bin/ncp/BACKUPS</code></summary>

- [x] /nc-backup.sh
- [x] /nc-backup-auto.sh
- [x] /nc-export-ncp.sh
- [x] /nc-import-ncp.sh
- [x] /nc-restore.sh
- [x] /nc-restore-snapshot.sh
- [x] /nc-rsync.sh
- [x] /nc-rsync-auto.sh
- [x] /nc-snapshot.sh
- [x] /nc-snapshot-auto.sh
- [x] /nc-snapshot-sync.sh

</details>

<details><summary><code>/bin/ncp/CONFIG</code></summary>

- [x] /nc-admin.sh
- [x] /nc-database.sh
- [x] /nc-datadir.sh
- [x] /nc-httpsonly.sh
- [x] /nc-init.sh
- [x] /nc-limits.sh
- [x] /nc-nextcloud.sh
- [x] /nc-passwd.sh
- [x] /nc-prettyURL.sh
- [x] /nc-previews-auto.sh
- [x] /nc-scan-auto.sh
- [x] /nc-trusted-domains.sh
- [x] /nc-webui.sh

</details>

<details><summary><code>/bin/ncp/NETWORKING</code></summary>

- [x] /dnsmasq.sh
- [x] /duckDNS.sh
- [x] /freeDNS.sh
- [x] /letsencrypt.sh
- [x] /namecheapDNS.sh
- [x] /nc-forward-ports.sh
- [x] /nc-static-IP.sh
- [x] /nc-trusted-proxies.sh
- [x] /NFS.sh
- [x] /no-ip.sh
- [x] /samba.sh
- [x] /spDYN.sh
- [ ] /SSH.sh ×

</details>

<details><summary><code>/bin/ncp/SECURITY</code></summary>

- [ ] /fail2ban.sh
- [ ] /modsecurity.sh
- [ ] /nc-audit.sh
- [ ] /nc-encrypt.sh
- [ ] /UFW.sh

</details>

<details><summary><code>/bin/ncp/SYSTEM</code></summary>

- [x] /metrics.sh
- [x] /nc-automount.sh
- [ ] /nc-hdd-monitor.sh
- [ ] /nc-hdd-test.sh
- [x] /nc-info.sh
- [x] /nc-ramlogs.sh
- [x] /nc-swapfile.sh
- [x] /nc-zram.sh

</details>

<details><summary><code>/bin/ncp/TOOLS</code></summary>

- [ ] /clear-php-opcache.sh
- [ ] /nc-fix-permissions.sh
- [ ] /nc-format-USB.sh
- [x] /nc-maintenance.sh
- [x] /nc-previews.sh
- [x] /nc-scan.sh

</details>

<details><summary><code>/bin/ncp/UPDATES</code></summary>

- [x] /nc-autoupdate-nc.sh
- [x] /nc-autoupdate-ncp.sh
- [x] /nc-notify-updates.sh
- [x] /nc-update.sh
- [x] /nc-update-nc-apps.sh
- [x] /nc-update-nc-apps-auto.sh
- [x] /nc-update-nextcloud.sh
- [x] /unattended-upgrades.sh

</details>

<details><summary><code>/build</code></summary>

- [ ] /batch.sh
- [ ] /build-docker.sh
- [x] /buildlib.sh
- [ ] /build-LXC.sh
- [ ] /build-LXD.sh
- [ ] /build-SD-armbian.sh
- [ ] /build-SD-berryboot.sh
- [x] /build-SD-rpi.sh
- [ ] /build-VM.sh
- [ ] /lxc_config
- [ ] /Vagrantfile

</details>

<details><summary><code>/build/armbian</code></summary>

- [ ] /armbian.sh
- [ ] /config-odroidc2.conf
- [ ] /config-orangepizeroplus2-h5.conf

</details>

<details><summary><code>/build/docker</code></summary>

- [ ] /docker-compose.yml
- [ ] /docker-compose-ncpdev.yml
- [ ] /Dockerfile

</details>

<details><summary><code>/build/docker/debian-ncp</code></summary>

- [ ] /run-parts.sh

</details>

<details><summary><code>/build/docker/lamp</code></summary>

- [ ] /010lamp

</details>

<details><summary><code>/build/docker/nextcloud</code></summary>

- [ ] /020nextcloud

</details>

<details><summary><code>/build/docker/nextcloudpi</code></summary>

- [ ] /000ncp

</details>

<details><summary><code>/etc</code></summary>

- [x] /library.sh
- [ ] /ncp.cfg

</details>

<details><summary><code>/etc/ncp-templates</code></summary>

- [x] /ncp-metrics.cfg.sh
- [x] /nextcloud.conf.sh

</details>

`/ncp-previewgenerator/ncp-previewgenerator-nc20`

`/ncp-previewgenerator/ncp-previewgenerator-nc21`

---

## Docker stuffz

`docker build .`

`sudo docker build .`

`docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it [container id/name]`

### Image ID's

`docker images | awk '{print $3}' | tail -n +2`

### Latest image ID

`docker images | awk '{print $3}' | tail -n +2 | head -1`

<!-- 1: 20:13 - 20:41 28 minutes -->
<!-- 2: 23:07 - 23:34 27 minutes -->

`docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it "$(docker images | awk '{print $3}' | tail -n +2 | head -1)" docker-compose up -d --build`

`docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it "$(docker images | awk '{print $3}' | tail -n +2 | head -1)"`

### Container ID's

`docker ps | awk '{print $1}' | tail -n +2`

### Latest 3 container ID

`docker ps | awk '{print $1}' | tail -n +2 | head -3`

### Latest 1st container ID

`docker ps | awk '{print $1}' | tail -n +2 | head -1`

### Latest 2nd container ID

`docker ps | awk '{print $1}' | tail -n +3 | head -1`

### Latest 3rd container ID

`docker ps | awk '{print $1}' | tail -n +4 | head -1`

### ID and image name

`docker ps | awk '{print $2,$1}' | tail -n +4 | head -1`

### Image ID and name

`docker images | awk '{print $1,$3}' | tail -n +4 | head -1`

### Kill latest 3

`for LINE in $(docker ps | awk '{print $1}' | tail -n +2 | head -3); do docker kill "$LINE"; done`

### Remove latest image

`docker rmi "$(docker images | awk '{print $3}' | tail -n +2 | head -1)"`

`curl --verbose --location 192.168.178.34`
