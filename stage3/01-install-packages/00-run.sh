#!/bin/bash -e

# add for mongodb source location
on_chroot <<EOF 
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
EOF

echo \
"deb [ arch=arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee "$ROOTFS_DIR/etc/apt/sources.list.d/mongodb-org-4.4.list"

on_chroot <<EOF
apt-get update
EOF