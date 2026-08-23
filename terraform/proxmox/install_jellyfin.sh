#!/bin/bash
ip link set eth0 up
ip addr add 192.168.1.41/24 dev eth0
ip route add default via 192.168.1.1
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get update
apt-get install -y curl gnupg lsb-release

curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg
echo "deb [arch=amd64] https://repo.jellyfin.org/debian bookworm main" > /etc/apt/sources.list.d/jellyfin.list

apt-get update
apt-get install -y jellyfin
systemctl enable --now jellyfin