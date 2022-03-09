#!/bin/bash -e

WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate

# Install newer version for libseccomp2
echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a "$ROOTFS_DIR/etc/apt/sources.list.d/debian-backports.list"
on_chroot <<EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
apt-get update
apt-get install -y -qq --no-install-recommends -t buster-backports libseccomp2
EOF

# Install Network Manager config
install -m 644 files/NetworkManager.conf "$ROOTFS_DIR/etc/NetworkManager/"

# Change the kernel virtual memory accounting mode to: always overcommit, never check
echo "vm.overcommit_memory = 1" >> $ROOTFS_DIR/etc/sysctl.conf

# Show text-ui on login
echo -e "sudo bash /var/lib/wazigate/wazigate-host/text-ui.sh" >> "$ROOTFS_DIR/home/$FIRST_USER_NAME/.profile"
