#!/bin/sh
# ----------------------------------------------------------------------------
# entrypoint for squid container
# ----------------------------------------------------------------------------
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{ print $4 }')

sudo /init-squid.sh

# start confighandler daemon
sudo confighandler "$@" || exit 1

# create cache dir
# -N        Master process runs in foreground and is a worker. No kids.
# -z        Create missing swap directories and then exit.
/usr/sbin/squid -N -z

# -N        Master process runs in foreground and is a worker. No kids.
# -Y        Only return UDP_HIT or UDP_MISS_NOFETCH during fast reload.
# -C        Do not catch fatal signals.
exec /usr/sbin/squid -NYC

