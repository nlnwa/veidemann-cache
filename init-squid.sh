#!/bin/sh
# ----------------------------------------------------------------------------
# Initialize squid environment
# This script must be run as root
# ----------------------------------------------------------------------------
set -e

DNS_SERVERS=$1
if [ -n "$DNS_SERVERS" ]; then
  for s in $DNS_SERVERS; do
    export DNS_IP="$(nslookup ${s} | grep "Address 1" | cut -f3 -d' ') ${DNS_IP}"
  done
fi
/usr/bin/envsubst '${DNS_IP}' < /etc/squid/squid.conf.template > /etc/squid/squid.conf
/bin/chown -R squid:squid /var/cache/squid
/bin/chown -R squid:squid /var/log/squid
/usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db
chown -R squid:squid /var/lib/ssl_db
