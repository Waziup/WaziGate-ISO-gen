#!/bin/bash -e

rm -f "${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d/wait.conf"


cd ${ROOTFS_DIR}/home/${FIRST_USER_NAME}
echo $PWD

git clone https://github.com/Waziup/WaziGate.git waziup-gateway
cd waziup-gateway

docker-compose pull

chmod a+x setup/install.sh
chmod a+x setup/uninstall.sh

mkdir -p apps/waziup
cd apps/waziup

git clone https://github.com/Waziup/wazigate-system.git
cd wazigate-system
rm -rf api docs ui Dockerfile conf.json wazigate-system Dockerfile-dev go.* *.go package-lock.json
