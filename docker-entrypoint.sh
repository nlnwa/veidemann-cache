#!/bin/sh
# ----------------------------------------------------------------------------
# entrypoint for squid container
# ----------------------------------------------------------------------------
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{ print $4 }')
if [ "$1" == "squid" ]; then
  export THIS_IP=$(ip -f inet -br addr show dev eth0 | awk '{ print $3 }' | cut -f1 -d'/')

  echo "Staring squid [${SQUID_VERSION}]"
  if [ -n "$DNS_SERVERS" ]; then
    for s in $DNS_SERVERS; do
      export DNS_IP="$(nslookup ${s} | grep "Address 1" | cut -f3 -d' ') ${DNS_IP}"
    done
    env
  fi
  envsubst '${DNS_IP}' < /etc/squid/squid.conf.template > /etc/squid/squid.conf
  chown -R squid:squid /var/cache/squid
  /sbin/su-exec root /usr/sbin/squid -N -z
  /usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db
  chown -R squid.squid /var/lib/ssl_db

  /usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db

  cat /etc/squid/squid.conf
  exec /sbin/su-exec root /usr/sbin/squid -N
else
  exec "$@"
fi
