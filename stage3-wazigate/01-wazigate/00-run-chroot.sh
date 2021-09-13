#!/bin/bash -e

#systemctl stop docker.service
#systemctl disable docker.service
#curl -fsSL get.docker.com -o get-docker.sh 
#./get-docker.sh
#sleep 1
#usermod -aG docker $USER
#rm get-docker.sh
#sleep 1
#echo "Done"

echo $PWD

rm -rf waziup-gateway
git clone https://github.com/Waziup/WaziGate.git waziup-gateway
cd waziup-gateway

chmod a+x setup/install.sh
chmod a+x setup/uninstall.sh

mkdir -p apps/waziup
cd apps/waziup

git clone https://github.com/Waziup/wazigate-system.git
cd wazigate-system
rm -rf api docs ui Dockerfile conf.json wazigate-system Dockerfile-dev go.* *.go package-lock.json


