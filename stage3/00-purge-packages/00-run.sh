#!/bin/bash -e

# Packages interfering with network manager
on_chroot <<EOF
apt purge -y openresolv dhcpcd5
EOF