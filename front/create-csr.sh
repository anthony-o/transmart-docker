#!/bin/bash
set -x
set -e

# Short date expression thanks to https://stackoverflow.com/a/1401495/535203
BACKUP_DIR=$HTTPD_PREFIX/conf/certs/backups/`date +%Y%m%d-%H%M%S`

# Backup old certs
for F in server.key server.csr server.crt server-ca.crt; do
    if [ -f "$HTTPD_PREFIX/conf/certs/$F" ]; then
        if [ ! -d "$BACKUP_DIR" ]; then
            mkdir -p $BACKUP_DIR
        fi
        mv "$HTTPD_PREFIX/conf/certs/$F" "$BACKUP_DIR/"
    fi
done

echo "Host's hostname: $HOST_HOSTNAME"

# Generate a new key and csr thanks to https://www.madboa.com/geek/openssl/ and https://www.tbs-certificates.co.uk/FAQ/en/sha256.html
openssl req \
  -new -sha256 -newkey rsa:2048 -nodes \
  -keyout "$HTTPD_PREFIX/conf/certs/server.key" -out "$HTTPD_PREFIX/conf/certs/server.csr"