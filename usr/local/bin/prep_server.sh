#!/bin/bash

echo -n "Updating system"
apt-get update && apt-get dist-upgrade -y
echo .

echo -n "Minimizing kernel"
apt-get install -f -y linux-virtual
apt-get remove -y linux-firmware
dpkg -l | grep extra | grep linux | awk '{print $2}' | xargs apt-get remove -y
echo .

echo -n "Install what we need"
apt-get install -y fdisk parted partprobe xe-guest-utilities
echo .

echo -n "Removing other packages"
apt-get remove --purge -y lxd
apt-get remove --purge -y mdadm
apt-get autoremove --purge -y
echo .

echo -n "fstab fixes"
# update fstab for the root partition
perl -pi -e 's/(errors=remount-ro)/noatime,nodiratime,$1,barrier=0/' /etc/fstab
echo .

echo -n "Generalize hosts file"
echo "localhost.localdomain" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# The following lines are desirable for IPv6 capable hosts
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
echo .

echo -n "Generalize network configuration"
cat > /etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
# This is an autoconfigured IPv6 interface
iface eth0 inet6 auto
EOF

# generalization
echo -n "Generalizing filesystem"
rm -f /etc/ssh/ssh_host_*
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/*cache.bin
rm -f /var/lib/apt/lists/*_Packages
rm -f rm -rf /var/lib/dhcp/*.leases
rm -f /var/spool/mail/*
echo "" > /root/.bash_history
echo "" > /home/toor/.bash_history
history -r
history -c
history -a
echo .

echo -n "Enable firstboot service"
/bin/systemctl enable firstboot
echo .

/sbin/poweroff
