#!/bin/sh
# ----------------------------------------------------------------------------
# entrypoint for squid container
# ----------------------------------------------------------------------------
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{ print $4 }')
if [ "$1" = "squid" ]; then
  shift

  # initialize squid
  sudo CACHE_DIR_MB="${CACHE_DIR_MB:-100}" /init-squid.sh

  # start confighandler daemon
  sudo confighandler "$@" || exit 1

  # give confighandler time to do it's initial config rewrite
  sleep 1

  # create cache dir
  /usr/sbin/squid -N -z

  echo "Starting squid [${SQUID_VERSION}]"
  exec /usr/sbin/squid -NYC
else
  exec "$@"
fi
