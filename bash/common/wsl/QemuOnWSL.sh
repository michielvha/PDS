# TODO: Rework this old snippet to current standards.
# This script installs QEMU and Virt-Manager on WSL2 with Debian or Ubuntu.
#!/bin/bash
# RUN AS ROOT
apt-get update

sudo apt install qemu qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager
apt install x11-apps

#make debian use systemd on boot
sudo echo '[boot]
systemd=true' > /etc/wsl.conf

wsl --shutdown -d "your distribution name"

#####################################
#   --- restart the instance ---   #
#####################################

sudo systemctl enable --now libvirtd
sudo systemctl enable --now virtlogd

virt-manager

#make debian test vm
 sudo virt-install --name=debian-vm \
 --os-type=Linux \
 --os-variant=debian10 \
 --vcpu=2 \
 --ram=2048 \
 --disk path=/var/lib/libvirt/images/Debian.img,size=15 \
 --graphics spice \
 --cdrom=/var/lib/iso/debian-11.5.0-amd64-netinst.iso