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

- [ ] /nc-backup.sh
- [ ] /nc-backup-auto.sh
- [ ] /nc-export-ncp.sh
- [ ] /nc-import-ncp.sh
- [ ] /nc-restore.sh
- [ ] /nc-restore-snapshot.sh
- [ ] /nc-rsync.sh
- [ ] /nc-rsync-auto.sh
- [ ] /nc-snapshot.sh
- [ ] /nc-snapshot-auto.sh
- [ ] /nc-snapshot-sync.sh

</details>

<details><summary><code>/bin/ncp/CONFIG</code></summary>

- [ ] /nc-admin.sh
- [ ] /nc-database.sh
- [ ] /nc-datadir.sh
- [ ] /nc-httpsonly.sh
- [ ] /nc-init.sh
- [ ] /nc-limits.sh
- [ ] /nc-nextcloud.sh
- [ ] /nc-passwd.sh
- [ ] /nc-prettyURL.sh
- [ ] /nc-previews-auto.sh
- [ ] /nc-scan-auto.sh
- [ ] /nc-trusted-domains.sh
- [ ] /nc-webui.sh

</details>

<details><summary><code>/bin/ncp/NETWORKING</code></summary>

- [ ] /dnsmasq.sh
- [ ] /duckDNS.sh
- [ ] /freeDNS.sh
- [ ] /letsencrypt.sh
- [ ] /namecheapDNS.sh
- [ ] /nc-forward-ports.sh
- [ ] /nc-static-IP.sh
- [ ] /nc-trusted-proxies.sh
- [ ] /NFS.sh
- [ ] /no-ip.sh
- [ ] /samba.sh
- [ ] /spDYN.sh
- [ ] /SSH.sh

</details>

<details><summary><code>/bin/ncp/SECURITY</code></summary>

- [ ] /fail2ban.sh
- [ ] /modsecurity.sh
- [ ] /nc-audit.sh
- [ ] /nc-encrypt.sh
- [ ] /UFW.sh

</details>

<details><summary><code>/bin/ncp/SYSTEM</code></summary>

- [ ] /metrics.sh
- [ ] /nc-automount.sh
- [ ] /nc-hdd-monitor.sh
- [ ] /nc-hdd-test.sh
- [ ] /nc-info.sh
- [ ] /nc-ramlogs.sh
- [ ] /nc-swapfile.sh
- [ ] /nc-zram.sh

</details>

<details><summary><code>/bin/ncp/TOOLS</code></summary>

- [ ] /clear-php-opcache.sh
- [ ] /nc-fix-permissions.sh
- [ ] /nc-format-USB.sh
- [ ] /nc-maintenance.sh
- [ ] /nc-previews.sh
- [ ] /nc-scan.sh

</details>

<details><summary><code>/bin/ncp/UPDATES</code></summary>

- [ ] /nc-autoupdate-nc.sh
- [ ] /nc-autoupdate-ncp.sh
- [ ] /nc-notify-updates.sh
- [ ] /nc-update.sh
- [ ] /nc-update-nc-apps.sh
- [ ] /nc-update-nc-apps-auto.sh
- [ ] /nc-update-nextcloud.sh
- [ ] /unattended-upgrades.sh

</details>

<details><summary><code>/build</code></summary>

- [ ] /batch.sh
- [ ] /build-docker.sh
- [ ] /buildlib.sh
- [ ] /build-LXC.sh
- [ ] /build-LXD.sh
- [ ] /build-SD-armbian.sh
- [ ] /build-SD-berryboot.sh
- [ ] /build-SD-rpi.sh
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

- [ ] /library.sh
- [ ] /ncp.cfg

</details>

<details><summary><code>/etc/ncp-config.d</code></summary>

- [ ] /clear-php-opcache.cfg
- [ ] /dnsmasq.cfg
- [ ] /duckDNS.cfg
- [ ] /fail2ban.cfg
- [ ] /freeDNS.cfg
- [ ] /letsencrypt.cfg
- [ ] /metrics.cfg
- [ ] /modsecurity.cfg
- [ ] /namecheapDNS.cfg
- [ ] /nc-admin.cfg
- [ ] /nc-audit.cfg
- [ ] /nc-automount.cfg
- [ ] /nc-autoupdate-nc.cfg
- [ ] /nc-autoupdate-ncp.cfg
- [ ] /nc-backup.cfg
- [ ] /nc-backup-auto.cfg
- [ ] /nc-database.cfg
- [ ] /nc-datadir.cfg
- [ ] /nc-encrypt.cfg
- [ ] /nc-export-ncp.cfg
- [ ] /nc-fix-permissions.cfg
- [ ] /nc-format-USB.cfg
- [ ] /nc-forward-ports.cfg
- [ ] /nc-hdd-monitor.cfg
- [ ] /nc-hdd-test.cfg
- [ ] /nc-httpsonly.cfg
- [ ] /nc-import-ncp.cfg
- [ ] /nc-info.cfg
- [ ] /nc-init.cfg
- [ ] /nc-limits.cfg
- [ ] /nc-maintenance.cfg
- [ ] /nc-nextcloud.cfg
- [ ] /nc-notify-updates.cfg
- [ ] /nc-passwd.cfg
- [ ] /nc-prettyURL.cfg
- [ ] /nc-previews.cfg
- [ ] /nc-previews-auto.cfg
- [ ] /nc-ramlogs.cfg
- [ ] /nc-restore.cfg
- [ ] /nc-restore-snapshot.cfg
- [ ] /nc-rsync.cfg
- [ ] /nc-rsync-auto.cfg
- [ ] /nc-scan.cfg
- [ ] /nc-scan-auto.cfg
- [ ] /nc-snapshot.cfg
- [ ] /nc-snapshot-auto.cfg
- [ ] /nc-snapshot-sync.cfg
- [ ] /nc-static-IP.cfg
- [ ] /nc-swapfile.cfg
- [ ] /nc-trusted-domains.cfg
- [ ] /nc-trusted-proxies.cfg
- [ ] /nc-update.cfg
- [ ] /nc-update-nc-apps.cfg
- [ ] /nc-update-nc-apps-auto.cfg
- [ ] /nc-update-nextcloud.cfg
- [ ] /nc-webui.cfg
- [ ] /nc-zram.cfg
- [ ] /NFS.cfg
- [ ] /no-ip.cfg
- [ ] /samba.cfg
- [ ] /spDYN.cfg
- [ ] /SSH.cfg
- [ ] /UFW.cfg
- [ ] /unattended-upgrades.cfg

</details>

<details><summary><code>/etc/ncp-templates</code></summary>

- [ ] /ncp-metrics.cfg.sh
- [ ] /nextcloud.conf.sh

</details>

<details><summary><code>/etc/ncp-templates/apache2</code></summary>

- [ ] /http2.conf.sh

</details>

<details><summary><code>/etc/ncp-templates/mysql</code></summary>

- [ ] /mysql/90-ncp.cnf.sh
- [ ] /mysql/91-ncp.cnf.sh

</details>

<details><summary><code>/etc/ncp-templates/php</code></summary>

- [ ] /90-ncp.ini.sh
- [ ] /opcache.ini.sh
- [ ] /pool.d.www.conf.sh

</details>

<details><summary><code>/etc/ncp-templates/systemd</code></summary>

- [ ] /notify_push.service.sh

</details>

<details><summary><code>/ncp-app/appinfo</code></summary>

- [ ] /info.xml
- [ ] /routes.php

</details>

<details><summary><code>/ncp-app/css</code></summary>

- [ ] /style.css

</details>

<details><summary><code>/ncp-app/js</code></summary>

- [ ] /script.js

</details>

<details><summary><code>/ncp-app/lib/Controller</code></summary>

- [ ] /PageController.php

</details>

<details><summary><code>/ncp-app/templates</code></summary>

- [ ] /index.php

</details>

<details><summary><code>/ncp-activation</code></summary>

- [ ] /CSS.css
- [ ] /index.php
- [ ] /JS.js

</details>

<details><summary><code>/ncp-web</code></summary>

- [ ] /backups.php
- [ ] /csrf.php
- [ ] /download.php
- [ ] /download_logs.php
- [ ] /elements.php
- [ ] /index.php
- [ ] /L10N.php
- [ ] /ncp-launcher.php
- [ ] /ncp-output.php
- [ ] /upload.php
- [ ] /langs.cfg

</details>

<details><summary><code>/ncp-web/activate</code></summary>

- [ ] /CSS.css
- [ ] /index.php
- [ ] /JS.js

</details>

<details><summary><code>/ncp-web/bootstrap</code></summary>

- [ ] /css/bootstrap.css
- [ ] /css/bootstrap.css.map
- [ ] /css/bootstrap.min.css
- [ ] /css/bootstrap-theme.css
- [ ] /css/bootstrap-theme.css.map
- [ ] /css/bootstrap-theme.min.css
- [ ] /fonts/glyphicons-halflings-regular.eot
- [ ] /fonts/glyphicons-halflings-regular.svg
- [ ] /fonts/glyphicons-halflings-regular.ttf
- [ ] /fonts/glyphicons-halflings-regular.woff
- [ ] /js/bootstrap.js
- [ ] /js/bootstrap.min.js
- [ ] /js/npm.js

</details>

<details><summary><code>/ncp-web/css</code></summary>

- [ ] /ncp.css

</details>

<details><summary><code>/ncp-web/decrypt</code></summary>

- [ ] /CSS.css
- [ ] /index.php
- [ ] /JS.js

</details>

<details><summary><code>/ncp-web/js</code></summary>

- [ ] /minified.js
- [ ] /ncp.js

</details>

<details><summary><code>/ncp-web/wizard</code></summary>

- [ ] /index.php

</details>

<details><summary><code>/ncp-web/wizard/CSS</code></summary>

- [ ] /wizard.css

</details>

<details><summary><code>/ncp-web/wizard/JS</code></summary>

- [ ] /jquery.bootstrap.wizard.js
- [ ] /jquery-latest.js
- [ ] /wizard.js

</details>

<details><summary><code>/tests</code></summary>

- [ ] /activation_tests.py
- [ ] /libvirt_forwarding.sh
- [ ] /lxd_forwarding.sh
- [ ] /nc_backup_test.robot
- [ ] /NcpRobotLib.py
- [ ] /nextcloud_tests.py
- [ ] /requirements.txt
- [ ] /system_tests.py

</details>

<details><summary><code>/updates</code></summary>

- [ ] /1.13.6.sh
- [ ] /1.16.0.sh
- [ ] /1.18.0.sh
- [ ] /1.20.0.sh
- [ ] /1.25.0.sh
- [ ] /1.30.0.sh
- [ ] /1.36.4.sh
- [ ] /1.39.0.sh
- [ ] /1.40.0.sh
- [ ] /1.43.0.sh
- [ ] /1.45.0.sh
- [ ] /1.46.0.sh
- [ ] /1.47.0.sh
- [ ] /1.48.2.sh
- [ ] /1.50.0.sh
- [ ] /1.50.1.sh
- [ ] /1.50.5.sh
- [ ] /1.51.0.sh

</details>

`/ncp-previewgenerator/ncp-previewgenerator-nc20`

`/ncp-previewgenerator/ncp-previewgenerator-nc21`



# # # # # # # # # # # # # # # # # # # # # # # # 
 # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # 
 # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # 

docker build .
sudo docker build .
docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it [container id/name]

# Image ID's
docker images | awk '{print $3}' | tail -n +2

# Latest image ID
docker images | awk '{print $3}' | tail -n +2 | head -1

# 1: 20:13 - 20:41 28 minutes
# 2: 23:07 - 23:34 27 minutes

docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it "$(docker images | awk '{print $3}' | tail -n +2 | head -1)" docker-compose up -d --build

docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it "$(docker images | awk '{print $3}' | tail -n +2 | head -1)"

### Container ID's
docker ps | awk '{print $1}' | tail -n +2

### Latest 3 container ID
docker ps | awk '{print $1}' | tail -n +2 | head -3

### Latest 1st container ID
docker ps | awk '{print $1}' | tail -n +2 | head -1

### Latest 2nd container ID
docker ps | awk '{print $1}' | tail -n +3 | head -1

### Latest 3rd container ID
docker ps | awk '{print $1}' | tail -n +4 | head -1

### ID and image name
docker ps | awk '{print $2,$1}' | tail -n +4 | head -1

### Image ID and name
docker images | awk '{print $1,$3}' | tail -n +4 | head -1

### Kill latest 3
for LINE in $(docker ps | awk '{print $1}' | tail -n +2 | head -3); do docker kill "$LINE"; done

### Remove latest image
docker rmi "$(docker images | awk '{print $3}' | tail -n +2 | head -1)"

curl --verbose --location 192.168.178.34
