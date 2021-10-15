#!/bin/bash -e

DEFAULT_WAZIGATE_BRANCH="master"
if [ -z "$WAZIGATE_BRANCH" ]; then
	WAZIGATE_BRANCH=$DEFAULT_WAZIGATE_BRANCH
fi

WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate
# WAZIGATE_DIR=$ROOTFS_DIR/home/${FIRST_USER_NAME}/wazigate

################################################################################


# Download Wazigate Repo
git clone -b $WAZIGATE_BRANCH --single-branch https://github.com/Waziup/WaziGate.git $WAZIGATE_DIR
chmod +x $WAZIGATE_DIR/wazigate-host/wazigate-host
chmod +x $WAZIGATE_DIR/setup.sh

################################################################################


# Download Wazigate Docker Images from Docker Hub

if [ -f "files/wazigate-mongo.tar" ]; then
  echo "Using wazigate-mongo docker image from wazigate-mongo.tar"
else
  echo "Pulling wazigate-mongo from docker hub ..."
  docker pull --platform linux/arm/v7 webhippie/mongodb
  docker image save webhippie/mongodb -o files/wazigate-mongo.tar
fi
if [ -f "files/wazigate-edge.tar" ]; then
  echo "Using wazigate-edge docker image from wazigate-edge.tar"
else
  echo "Pulling wazigate-edge from docker hub ..."
  docker pull --platform linux/arm/v7 waziup/wazigate-edge
  docker image save waziup/wazigate-edge -o files/wazigate-edge.tar
fi

# Copy Wazigate Docker Images
install -m 644 files/wazigate-mongo.tar $WAZIGATE_DIR/
install -m 644 files/wazigate-edge.tar  $WAZIGATE_DIR/

################################################################################


# Setup Work

rm -f "$ROOTFS_DIR/etc/systemd/system/dhcpcd.service.d/wait.conf"
mv --backup=numbered $ROOTFS_DIR/etc/dnsmasq.conf $ROOTFS_DIR/etc/dnsmasq.conf.orig
echo 'interface=wlan0\n  dhcp-range=192.168.200.2,192.168.200.200,255.255.255.0,24h\n' > $ROOTFS_DIR/etc/dnsmasq.conf

cp $WAZIGATE_DIR/setup/hostapd.conf $ROOTFS_DIR/etc/hostapd/hostapd.conf

if ! grep -qFx 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' $ROOTFS_DIR/etc/default/hostapd; then
  sed -i -e '$i \DAEMON_CONF="/etc/hostapd/hostapd.conf"\n' $ROOTFS_DIR/etc/default/hostapd
fi

cp --backup=numbered $ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf $ROOTFS_DIR/etc/wpa_supplicant/wpa_supplicant.conf.orig

echo "static domain_name_servers=8.8.8.8" >> $ROOTFS_DIR/etc/dhcpcd.conf

# cp setup/clouds.json wazigate-edge


# chmod a+x ./start.sh
# chmod a+x ./stop.sh

# Run setup.sh as systemd service on boot  
cp $WAZIGATE_DIR/wazigate-setup.service $ROOTFS_DIR/etc/systemd/system

# Run wazigate-host as systemd service on boot  
cp $WAZIGATE_DIR/wazigate-host/wazigate-host $ROOTFS_DIR/usr/bin
cp $WAZIGATE_DIR/wazigate-host/wazigate-host.service $ROOTFS_DIR/etc/systemd/system

# Enable Wazigate services
on_chroot <<EOF
systemctl enable wazigate-setup
systemctl enable wazigate-host
EOF

# Enable SPI
echo -e '\ndtparam=i2c_arm=on' >> $ROOTFS_DIR/boot/config.txt

# Enable I2C
echo ' bcm2708.vc_i2c_override=1' >> $ROOTFS_DIR/boot/cmdline.txt
echo -e '\ni2c-bcm2708' >> $ROOTFS_DIR/etc/modules-load.d/raspberrypi.conf
echo -e '\ni2c-dev' >> $ROOTFS_DIR/etc/modules-load.d/raspberrypi.conf

# Show text-ui on login
echo -e "sudo bash /var/lib/wazigate/wazigate-host/text-ui.sh" >> $ROOTFS_DIR/home/$FIRST_USER_NAME/.profile