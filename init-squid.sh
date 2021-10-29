#!/bin/sh
# ----------------------------------------------------------------------------
# Initialize squid environment
# This script must be run as root
# ----------------------------------------------------------------------------
set -e

# Create and initialize TLS certificates cache directory
/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB

# Set permissions to allow access by squid
chown -R squid:squid /var/lib/ssl_db
