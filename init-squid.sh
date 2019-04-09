#!/bin/sh
# ----------------------------------------------------------------------------
# Initialize squid environment
# This script must be run as root
# ----------------------------------------------------------------------------
set -e

rm -rf /var/cache/squid/*
/bin/chown -R squid:squid /var/cache/squid
/bin/chown -R squid:squid /var/log/squid

/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
chown -R squid:squid /var/lib/ssl_db
