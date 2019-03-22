#!/bin/bash

echo "<<< downloading cds binaries >>>"
mkdir /opt/cds
cd /opt/cds
LAST_RELEASE=$(curl -s https://api.github.com/repos/ovh/cds/releases | grep tag_name | head -n 1 | cut -d '"' -f 4)
OS=linux # could be linux, darwin, windows
ARCH=amd64 # could be 386, arm, amd64
# GET Binaries from GitHub
wget https://github.com/ovh/cds/releases/download/$LAST_RELEASE/cds-engine-$OS-$ARCH
wget https://github.com/ovh/cds/releases/download/$LAST_RELEASE/cds-worker-$OS-$ARCH
wget https://github.com/ovh/cds/releases/download/$LAST_RELEASE/cdsctl-$OS-$ARCH
wget https://github.com/ovh/cds/releases/download/$LAST_RELEASE/ui.tar.gz
wget https://github.com/ovh/cds/releases/download/$LAST_RELEASE/sql.tar.gz
chmod +x *-$OS-$ARCH

echo "<<< updating cds sql schema >>>"
tar -zxf sql.tar.gz
/opt/cds/cds-engine-linux-amd64 database upgrade --db-host 10.240.0.90 --db-user cds --db-password cds --db-name cds --db-sslmode disable --db-port 5432 --migrate-dir sql

echo "<<< installing cds ui>>>"
cd /opt/cds
tar xzf ui.tar.gz

cd dist/

wget https://github.com/ovh/cds/releases/download/0.8.0/caddy-linux-amd64
chmod +x caddy-linux-amd64

