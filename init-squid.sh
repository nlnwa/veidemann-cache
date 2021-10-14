#!/bin/sh
# ----------------------------------------------------------------------------
# Initialize squid environment
# This script must be run as root
# ----------------------------------------------------------------------------
set -e

/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
chown -R squid:squid /var/lib/ssl_db

envsubst '$CACHE_DIR_MB' < /etc/squid/squid.conf > /etc/squid/squid.conf.template
