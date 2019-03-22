#!/bin/bash

for instance in cds-postgresql cds-engine;
do

IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
sed -i "/$instance/d" /etc/hosts
sudo echo "${IPADDRESSES[0]} $instance" >> /etc/hosts

done
