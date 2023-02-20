#!/usr/bin/env bash

# shellcheck disable=SC1091
source '/usr/local/etc/library.sh'

# wait until user decrypts the instance first
while :
do if ! needs_decrypt
   then break
   fi
   sleep 1
done

# wicd service finishes before completing DHCP
while :
do LOCAL_IP="$(get_ip)"
   PUBLIC_IP="$(curl -m4 icanhazip.com 2>/dev/null)" # TODO Add for IPv6 as well
   if [[ "$PUBLIC_IP" != "" ]]
   then ncc config:system:set trusted_domains 11 --value="$PUBLIC_IP"
   fi
   if [[ "$LOCAL_IP" != "" ]]
   then break
   fi
   sleep 3
done

ncc config:system:set trusted_domains 1  --value="${local_ip}"
ncc config:system:set trusted_domains 14 --value="$(hostname -f)"

# we might need to retry if redis is not ready
while :
do if ! NC_DOMAIN="$(ncc config:system:get overwrite.cli.url)"
   then sleep 3
        continue
   fi
   # Fix the situation where junk was introduced in the config by mistake
   # because Redis was not yet ready to be used even if it was up
   if [[ "$NC_DOMAIN" =~ "RedisException" ]]
   then NC_DOMAIN="$(hostname)"
   fi
   set_nc_domain "$NC_DOMAIN" >> '/var/log/ncp.log'
   break
done

