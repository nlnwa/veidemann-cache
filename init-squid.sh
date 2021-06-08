#!/bin/sh
# ----------------------------------------------------------------------------
# Initialize squid environment
# This script must be run as root
# ----------------------------------------------------------------------------
set -e

# TODO move to initcontainer
rm -rf /var/cache/squid/*

/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
chown -R squid:squid /var/lib/ssl_db
# chmod 400 /var/lib/ssl_db
