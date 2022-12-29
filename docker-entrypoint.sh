#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# entrypoint for squid container
# ----------------------------------------------------------------------------
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{ print $4 }')

# Create and initialize TLS certificates cache directory
/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
# Set permissions to allow access by squid
chown -R proxy:proxy /var/lib/ssl_db

# Start confighandler daemon
confighandler "$@"


# Create cache dir
# -N        Master process runs in foreground and is a worker. No kids.
# -z        Create missing swap directories and then exit.
/usr/sbin/squid -N -z

ulimit -n "${MAX_OPEN_FILES:-65535}"

# Start squid
# -N        Master process runs in foreground and is a worker. No kids.
# -Y        Only return UDP_HIT or UDP_MISS_NOFETCH during fast reload.
# -C        Do not catch fatal signals.
exec /usr/sbin/squid -NYC

