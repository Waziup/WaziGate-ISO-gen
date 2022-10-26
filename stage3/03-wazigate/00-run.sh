#!/bin/bash -e

WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate

# Install newer version for libseccomp2
echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a "$ROOTFS_DIR/etc/apt/sources.list.d/debian-backports.list"
on_chroot <<EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
apt-get update
apt-get install -y -qq --no-install-recommends -t buster-backports libseccomp2
EOF

# Overwrite mongodb service and conf file on host
install -m 644 files/mongod.service "$ROOTFS_DIR/lib/systemd/system/"
install -m 644 files/mongod.conf "$ROOTFS_DIR/etc/"

# Overwrite redis.conf file on host 
install -m 644 files/redis.conf "$ROOTFS_DIR/etc/redis/"
# Make folder for socket file and working dir, change owner and group, on_chroot: because no user redis
on_chroot <<EOF
install -d -m 644 -o redis -g redis "/var/run/redis/"
install -d -m 755 -o redis -g redis "/var/lib/redis/"
chown redis:redis /var/run/redis
EOF
# Replace redis.service file
install -m 644 files/redis-server.service "$ROOTFS_DIR/lib/systemd/system/"

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

# Copy text-ui shell script to host 
install -m 755 files/wazi-config.sh "$ROOTFS_DIR/usr/bin/wazi-config"
# Show text-ui on login
echo -e "# Add wazi-config on startup:\nsudo wazi-config" >> "$ROOTFS_DIR/home/$FIRST_USER_NAME/.profile"

# Copy reconnect_wifi shell script to host 
install -m 755 files/reconnect_wifi.sh "$ROOTFS_DIR/usr/bin/reconnect_wifi"
install -m 755 files/reconnect_wifi.service "$ROOTFS_DIR/etc/systemd/system/reconnect_wifi.service"
install -m 755 files/reconnect_wifi.timer "$ROOTFS_DIR/etc/systemd/system/reconnect_wifi.timer"
touch "$ROOT_FS/etc/do_not_reconnect_wifi"



# Enable Wazigate services
on_chroot <<EOF
systemctl enable mongod
systemctl enable wazigate
systemctl enable reconnect_wifi.timer
EOF

# Create log file for wazigate-setup
#touch "$ROOTFS_DIR/tmp/wazigate-setup-step.txt"