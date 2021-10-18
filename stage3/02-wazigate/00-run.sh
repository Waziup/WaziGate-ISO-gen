#!/bin/bash -e

DEFAULT_WAZIGATE_BRANCH="master"
if [ -z "$WAZIGATE_BRANCH" ]; then
	WAZIGATE_BRANCH=$DEFAULT_WAZIGATE_BRANCH
fi

DEFAULT_WAZIGATE_TAG="latest"
if [ -z "$WAZIGATE_TAG" ]; then
	WAZIGATE_TAG=$DEFAULT_WAZIGATE_TAG
fi

WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate
# WAZIGATE_DIR=$ROOTFS_DIR/home/${FIRST_USER_NAME}/wazigate

################################################################################


# Download Wazigate Repo
git clone -b $WAZIGATE_BRANCH --single-branch https://github.com/Waziup/WaziGate.git $WAZIGATE_DIR
chmod +x $WAZIGATE_DIR/wazigate-host/wazigate-host
chmod +x $WAZIGATE_DIR/setup.sh

################################################################################

function install_docker_image {

  # Cleaning existing image
  if [ "${CLEAN}" = "1" ] && [ -f "files/$1.tar" ]; then
    rm -f "files/$1.tar";
  fi
  # Download Docker Image from Docker Hub
  if [ -f "files/$1.tar" ]; then
    echo "Using $1 docker image from $1.tar"
  else
    echo "Pulling $2 from docker hub ..."
    docker pull --platform linux/arm/v7 $2
    docker image save $2 -o files/$1.tar
  fi

  # Copy Docker Images
  install -m 644 files/$1.tar  $WAZIGATE_DIR/
}

install_docker_image "wazigate-mongo" "webhippie/mongodb:latest"
install_docker_image "wazigate-edge" "waziup/wazigate-edge:$WAZIGATE_TAG"
install_docker_image "wazigate-system" "waziup/wazigate-system:$WAZIGATE_TAG"


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
