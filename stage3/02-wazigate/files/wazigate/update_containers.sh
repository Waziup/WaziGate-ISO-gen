#!/bin/bash
set -x

docker rm -f wazigate-edge
docker image rm waziup/wazigate-edge:$WAZIGATE_TAG
docker run -d --restart=always --network=wazigate --name wazigate-edge \
  -e "WAZIGATE_ID=$WAZIGATE_ID" \
  -e "WAZIGATE_VERSION=$WAZIGATE_VERSION" \
  -e "WAZIGATE_TAG=$WAZIGATE_TAG" \
  -e "WAZIUP_MONGO=unix:///tmp/mongodb-27017.sock" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "/tmp/mongodb-27017.sock:/tmp/mongodb-27017.sock" \
  -v "/var/run/wazigate-host.sock:/var/run/wazigate-host.sock" \
  -v "$PWD/apps:/root/apps" \
  -p "80:80" -p "1883:1883" \
  waziup/wazigate-edge:$WAZIGATE_TAG

docker rm -f waziup.wazigate-system
docker image rm waziup/wazigate-system:$WAZIGATE_TAG
docker run -d --restart=unless-stopped --network=host --name waziup.wazigate-system \
  -v "/var/lib/wazigate/apps/waziup.wazigate-system:/var/lib/waziapp" \
  -v "/var/run:/var/run" \
  -v "/sys/class/gpio:/sys/class/gpio" \
  -v "/dev/mem:/dev/mem" \
  --privileged \
  --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
  --health-interval=10s \
  waziup/wazigate-system:$WAZIGATE_TAG

docker rm -f waziup.wazigate-lora
docker image rm waziup/wazigate-lora:$WAZIGATE_TAG
docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora \
  -v "/var/lib/wazigate/apps/waziup.wazigate-lora:/var/lib/waziapp" \
  --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
  --health-interval=10s \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  waziup/wazigate-lora:$WAZIGATE_TAG
