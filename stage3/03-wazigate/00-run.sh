#!/bin/bash -e

WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate

# Install newer version for libseccomp2
echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a "$ROOTFS_DIR/etc/apt/sources.list.d/debian-backports.list"
on_chroot <<EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
apt-get update
apt-get install -y -qq --no-install-recommends -t buster-backports libseccomp2
EOF

# Overwrite mongodb service file on host
install -m 644 files/mongod.service "$ROOTFS_DIR/lib/systemd/system/"

# Overwrite redis.conf file on host 
install -m 644 files/redis.conf "$ROOTFS_DIR/etc/redis/"
# Make folder for socket file and working dir, change owner and group, on_chroot: because no user redis
on_chroot <<EOF
install -d -m 644 -o redis -g redis "/var/run/redis/"
install -d -m 644 -o redis -g redis "/var/lib/redis/"
EOF
# Replace redis.service file
install -m 644 files/redis-server.service "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/"

# Install Network Manager config
install -m 644 files/NetworkManager.conf "$ROOTFS_DIR/etc/NetworkManager/"

# Change the kernel virtual memory accounting mode to: always overcommit, never check
echo "vm.overcommit_memory = 1" >> $ROOTFS_DIR/etc/sysctl.conf

# Reduce total amounts of writes

# Disable swap file
on_chroot <<EOF
dphys-swapfile swapoff 
dphys-swapfile uninstall
update-rc.d dphys-swapfile remove
systemctl disable dphys-swapfile
EOF

# Disable all journalctl logs
install -m 644 files/rsyslog.conf "$ROOTFS_DIR/etc/"

# on_chroot <<EOF
# # unmount echo u > "$ROOTFS_DIR/proc/sysrq-trigger"
# # sync echo s > "$ROOTFS_DIR/proc/sysrq-trigger"
# tune2fs -O ^has_journal /dev/mmcblk0p2
# e2fsck -fy /dev/mmcblk0p2
# echo s > "$ROOTFS_DIR/proc/sysrq-trigger"
# # reboot echo b > "$ROOTFS_DIR/proc/sysrq-trigger"
# EOF
sed -i 's/has_journal,\?//g;s/features \= *$//g' "$ROOTFS_DIR/etc/mke2fs.conf"


# Install rsync, alternative to cp, recommended by log2ram
apt install rsync

#Install Log2RAM and copy configuration
# wget https://github.com/azlux/log2ram/archive/master.tar.gz -O "$ROOTFS_DIR/home/$FIRST_USER_NAME/log2ram.tar.gz"
# tar -xf "$ROOTFS_DIR/home/$FIRST_USER_NAME/log2ram.tar.gz"
# bash "$ROOTFS_DIR/home/$FIRST_USER_NAME/log2ram-master/install.sh"
# rm -f "$ROOTFS_DIR/home/$FIRST_USER_NAME/log2ram.tar.gz"
# rm -rf "$ROOTFS_DIR/home/$FIRST_USER_NAME/log2ram-master"

echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ bullseye main" | sudo tee "$ROOTFS_DIR/etc/apt/sources.list.d/azlux.list"
sudo wget -O "$ROOTFS_DIR/usr/share/keyrings/azlux-archive-keyring.gpg"  https://azlux.fr/repo.gpg
on_chroot <<EOF
sudo apt update
sudo apt install log2ram
EOF
install -m 644 files/log2ram.conf "$ROOTFS_DIR/etc/"

# Show text-ui on login
echo -e "sudo bash /var/lib/wazigate/wazigate-host/text-ui.sh" >> "$ROOTFS_DIR/home/$FIRST_USER_NAME/.profile"


# Enable Wazigate services
on_chroot <<EOF
systemctl enable wazigate-host

systemctl enable mongod
systemctl enable wazigate
EOF

# Create log file for wazigate-setup
#touch "$ROOTFS_DIR/tmp/wazigate-setup-step.txt"