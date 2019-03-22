#!/bin/bash

echo -e 'n\np\n1\n\n\nt\n83\np\nw\n' | sudo fdisk /dev/sdb
sudo mkfs -t ext4 /dev/sdb1
sudo mkdir /var/lib/postgresql/
echo '/dev/sdb1    /var/lib/postgresql/   ext4    defaults     0        2' | sudo tee --append /etc/fstab
sudo mount -a
sudo apt-get install postgresql -y

echo "listen_addresses = '*'" | sudo tee --append /etc/postgresql/10/main/postgresql.conf

sudo tee --append /etc/postgresql/10/main/pg_hba.conf > /dev/null <<'EOF'
host    all             all              10.240.0.0/24                   md5
EOF

sudo service postgresql restart

cat > /tmp/create-cds-db.sql <<EOF
CREATE DATABASE cds;
CREATE ROLE "cds" WITH PASSWORD 'cds';
grant all privileges on database cds to cds;
ALTER ROLE "cds" WITH LOGIN;
EOF


sudo -u postgres psql -a -f /tmp/create-cds-db.sql
