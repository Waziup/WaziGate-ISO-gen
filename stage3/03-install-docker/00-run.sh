#!/bin/bash -e

# curl -fsSL https://get.docker.com -o $ROOTFS_DIR/tmp/get-docker.sh


# on_chroot <<EOF
# sh /tmp/get-docker.sh
# adduser "$FIRST_USER_NAME" docker
# EOF

lsb_dist="raspbian"
dist_version="$(sed 's/\/.*//' $ROOTFS_DIR/etc/debian_version | sed 's/\..*//')"
case "$dist_version" in
	11)
		dist_version="bullseye"
	;;
	10)
		dist_version="buster"
	;;
	9)
		dist_version="stretch"
	;;
	8)
		dist_version="jessie"
	;;
esac

CHANNEL="stable"
DOWNLOAD_URL="https://download.docker.com"

echo "Docker: Channel $CHANNEL, Dist $lsb_dist / $dist_version"

apt_repo="deb [arch=armhf signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $DOWNLOAD_URL/linux/$lsb_dist $dist_version $CHANNEL"

curl -fsSL "$DOWNLOAD_URL/linux/$lsb_dist/gpg" | gpg --dearmor --yes -o "$ROOTFS_DIR/usr/share/keyrings/docker-archive-keyring.gpg"
echo "$apt_repo" > "$ROOTFS_DIR/etc/apt/sources.list.d/docker.list"

on_chroot <<EOF
apt-get update -qq
apt-get install -y -qq --no-install-recommends apt-transport-https ca-certificates curl gnupg docker-ce
adduser "$FIRST_USER_NAME" docker
EOF

mkdir -p "${ROOTFS_DIR}/etc/docker"
install -m 644 files/daemon.json "${ROOTFS_DIR}/etc/docker/daemon.json"