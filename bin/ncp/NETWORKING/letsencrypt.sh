#!/usr/bin/env bash

# Let's encrypt certbot installation on NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/03/17/lets-encrypt-installer-for-apache/

# printlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

NCDIR="${NCDIR:-/var/www/nextcloud}"
NC_VHOSTCFG="${NC_VHOSTCFG:-/etc/apache2/sites-available/nextcloud.conf}"
NCP_VHOSTCFG="${NCP_VHOSTCFG:-/etc/apache2/sites-available/ncp.conf}"
LETSENCRYPT="${LETSENCRYPT:-/usr/bin/letsencrypt}"

function is_active {
    [[ "$ACTIVE" == "yes" ]] \
    && [[ "$( find /etc/letsencrypt/live/ -maxdepth 0 -empty | wc -l )" == 0 ]]
}

function tmpl_letsencrypt_domain {
    (
        # shellcheck disable=SC1091
        . /usr/local/etc/library.sh
        if is_active_app 'letsencrypt'
        then find_app_param 'letsencrypt' 'DOMAIN'
        fi
    )
}

function install {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    if ! cd '/etc'
    then println "Failed to change directory to: /etc"; return 1
    fi
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" letsencrypt
    rm --force      '/etc/cron.d/certbot'
    mkdir --parents '/etc/letsencrypt/live'
    
    is_docker && {
        # execute before lamp stack
        cat > '/etc/services-available.d/009letsencrypt' <<EOF
#!/usr/bin/env bash

source /usr/local/etc/library.sh
persistent_cfg /etc/letsencrypt

exit 0
EOF
        chmod +x '/etc/services-available.d/009letsencrypt'
    }
    return 0
}

function configure {
    local CERT_PATH KEY_PATH DOMAIN_STRING DOMAIN_INDEX
    [[ "$ACTIVE" != "yes" ]] && {
        rm --recursive --force  /etc/letsencrypt/live/*
        rm --force             '/etc/cron.weekly/letsencrypt-ncp'
        rm --force             '/etc/letsencrypt/renewal-hooks/deploy/ncp'
        [[ "$DOCKERBUILD" == 1 ]] && update-rc.d letsencrypt disable
        install_template nextcloud.conf.sh "$NC_VHOSTCFG"
        CERT_PATH="$(grep SSLCertificateFile   "$NC_VHOSTCFG" | awk '{ print $2 }')"
        KEY_PATH="$(grep SSLCertificateKeyFile "$NC_VHOSTCFG" | awk '{ print $2 }')"
        sed -i "s|SSLCertificateFile.*|SSLCertificateFile $CERT_PATH|"      "$NCP_VHOSTCFG"
        sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile $KEY_PATH|" "$NCP_VHOSTCFG"
        apachectl -k graceful
        println "Letsencrypt certificates disabled. Using self-signed certificates instead."
        exit 0
    }
    
    # shellcheck disable=SC2153
    if [[ -z "$DOMAIN" ]]
    then println "Empty domain"; return 1
    fi
    
    # Do it
    DOMAIN_STRING=""
    for DOMAINS in "$DOMAIN" "$OTHER_DOMAIN"
    do if [[ "$DOMAINS" != "" ]]
       then if [[ "$DOMAIN_STRING" == "" ]]
            then DOMAIN_STRING+="$DOMAINS" || DOMAIN_STRING+=",$DOMAINS"
            fi
       fi
    done
    "$LETSENCRYPT" certonly -n \
        --cert-name "$DOMAIN" \
        --force-renew \
        --no-self-upgrade \
        --webroot \
        -w "$NCDIR" \
        --hsts \
        --agree-tos \
        -m "$EMAIL" \
        -d "$DOMAIN_STRING" && {
            # Set up auto-renewal
            cat > '/etc/cron.weekly/letsencrypt-ncp' <<EOF
#!/usr/bin/env bash
source /usr/local/etc/library.sh

# renew and notify
"$LETSENCRYPT" renew --quiet

# notify if fails
[[ \$? -ne 0 ]] && notify_admin \
                     "SSL renewal error" \
                     "SSL certificate renewal failed. See /var/log/letsencrypt/letsencrypt.log"

# cleanup
rm --recursive --force "$NCDIR"/.well-known
EOF
            chmod 755 '/etc/cron.weekly/letsencrypt-ncp'
            
            mkdir --parents '/etc/letsencrypt/renewal-hooks/deploy'
            cat > '/etc/letsencrypt/renewal-hooks/deploy/ncp' <<EOF
#!/usr/bin/env bash
source /usr/local/etc/library.sh
notify_admin \
  "SSL renewal" \
  "Your SSL certificate(s) \$RENEWED_DOMAINS has been renewed for another 90 days"
exit 0
EOF
            chmod +x '/etc/letsencrypt/renewal-hooks/deploy/ncp'
            
            # Configure Apache
            install_template 'nextcloud.conf.sh'   "$NC_VHOSTCFG"
            CERT_PATH="$(grep SSLCertificateFile   "$NC_VHOSTCFG" | awk '{ print $2 }')"
            KEY_PATH="$(grep SSLCertificateKeyFile "$NC_VHOSTCFG" | awk '{ print $2 }')"
            sed -i "s|SSLCertificateFile.*|SSLCertificateFile $CERT_PATH|"      "$NCP_VHOSTCFG"
            sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile $KEY_PATH|" "$NCP_VHOSTCFG"
    
            # Configure Nextcloud
            DOMAIN_INDEX=11
            for DOM in "$DOMAIN" "${OTHER_DOMAINS_ARRAY[@]}"
            do if [[ "$DOM" != "" ]]
               then if [[ ! "$DOMAIN_INDEX" -lt 20 ]]
                    then println "WARNING: $DOM will not be included in trusted domains for Nextcloud (maximum reached)."
                         println "It will still be included in the SSL certificate"
                         continue
                    else ncc config:system:set trusted_domains "$DOMAIN_INDEX" --value="$DOM"
                         DOMAIN_INDEX="$(( "$DOMAIN_INDEX" + 1 ))"
                    fi
               fi
            done
            
            set_nc_domain "$DOMAIN"
            apachectl -k graceful
            rm --recursive --force "$NCDIR"/.well-known
            
            # Update configuration
            is_docker && update-rc.d letsencrypt enable; return 0
    }
    rm --recursive --force "$NCDIR"/.well-known; return 1
}

function cleanup {
    apt-get purge -y \
            augeas-lenses \
            libpython-dev \
            libpython2.7-dev \
            libssl-dev \
            python-dev \
            python2.7-dev \
            python-pip-whl
}


# License
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA  02111-1307  USA

