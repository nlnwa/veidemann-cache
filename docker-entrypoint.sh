#!/bin/sh
# ----------------------------------------------------------------------------
# entrypoint for squid container
# ----------------------------------------------------------------------------
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{ print $4 }')
if [ "$1" == "squid" ]; then
  echo "Staring squid [${SQUID_VERSION}]"

  sudo /init-squid.sh
  /usr/sbin/squid -N -z
  exec /usr/sbin/squid -NYC
else
  exec "$@"
fi
