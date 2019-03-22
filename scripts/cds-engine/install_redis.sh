#!/bin/bash

apt-get update
apt install redis-tools redis screen -y
redis-server -v
systemctl enable redis-server
