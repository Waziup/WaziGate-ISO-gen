#!/bin/bash -e

log () {
  echo "Step $1/13: $2" > /tmp/wazigate-setup-step.txt
}

source .env


################################################################################

log 0 "Prepare"

if [ -f  /sys/class/net/eth0/address ] ; then
  WAZIGATE_ID=$(cat /sys/class/net/eth0/address)
else
  if [ -f  /sys/class/net/wlan0/address ] ; then
    WAZIGATE_ID=$(cat /sys/class/net/wlan0/address)
  fi;
fi;
WAZIGATE_ID=${WAZIGATE_ID//:}

SSID="WAZIGATE_${WAZIGATE_ID^^}"


################################################################################

log 1 "Enabling interfaces"

# Enable SPI
echo "Enabling SPI ..."
raspi-config nonint do_spi 0
# Enable I2C
echo "Enabling I2C ..."
raspi-config nonint do_i2c 0


################################################################################

log 2 "Creating docker network"

# Create the docker network and containers if they do not exist
if ! docker network inspect wazigate > /dev/null; then
  echo "Creating network 'wazigate' ..."
  docker network create wazigate
fi


log 3 "Configuring Access Point"

# Create Access Point (if not exists)
if [ ! -f /etc/NetworkManager/system-connections/WAZIGATE_AP.nmconnection ]; then
  nmcli dev wifi hotspot ifname wlan0 con-name WAZIGATE-AP ssid $SSID password "loragateway"
  nmcli connection modify WAZIGATE-AP \
    connection.autoconnect true connection.autoconnect-priority -100 \
    802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared ipv6.method auto \
    wifi-sec.key-mgmt wpa-psk wifi-sec.proto wpa
  # using down/up instead of reapply because '802-11-wireless.band' can not be changed on the fly
  nmcli c down WAZIGATE-AP
  nmcli c up WAZIGATE-AP
fi

# if ! docker image inspect webhippie/mongodb --format {{.Id}} > /dev/null; then
#   echo "Creating container 'wazigate-mongo' (MongoDB) ..."
#   # docker image save webhippie/mongodb -o wazigate-mongo.tar
#   docker image load -i wazigate-mongo.tar
#   docker run -d --restart=always --network=wazigate --name wazigate-mongo \
#     -p "27017:27017" \
#     -v "$PWD/wazigate-mongo/data:/var/lib/mongodb" \
#     -v "$PWD/wazigate-mongo/backup:/var/lib/backup" \
#     -v "$PWD/wazigate-mongo/bin:/var/lib/bin" \
#     --health-cmd="echo 'db.stats().ok' | mongo localhost:27017/local --quiet" \
#     --health-interval=10s \
#     --entrypoint="sh" \
#     webhippie/mongodb \
#     /var/lib/bin/entrypoint.sh
# fi


log 5 "Creating Wazigate-Edge app"

if ! docker image inspect waziup/wazigate-edge:$WAZIGATE_TAG --format {{.Id}} > /dev/null; then
  echo "Creating container 'wazigate-edge' (Wazigate Edge) ..."
  # docker image save waziup/wazigate-edge -o wazigate-edge.tar
  docker image load -i wazigate-edge.tar
  rm wazigate-edge.tar
  docker run -d --restart=always --network=wazigate --name waziup.wazigate-edge \
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
fi


log 6 "Creating Wazigate-System app"

if ! docker image inspect waziup/wazigate-system:$WAZIGATE_TAG --format {{.Id}} > /dev/null; then
  echo "Creating container 'wazigate-system' (Wazigate System) ..."
  # docker image save waziup/wazigate-system -o wazigate-system.tar
  docker image load -i wazigate-system.tar
  rm wazigate-system.tar
  docker run -d --restart=unless-stopped --network=host --name waziup.wazigate-system \
    -v "$PWD/apps/waziup.wazigate-system:/var/lib/waziapp" \
    -v "/var/run:/var/run" \
    -v "/sys/class/gpio:/sys/class/gpio" \
    -v "/dev/mem:/dev/mem" \
    --privileged \
    --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
    --health-interval=10s \
    waziup/wazigate-system:$WAZIGATE_TAG
fi

################################################################################

if ! docker image inspect waziup/wazigate-lora:$WAZIGATE_TAG --format {{.Id}} > /dev/null; then
  docker volume create postgresqldata
  docker volume create redisdata

  log 7 "Creating Wazigate-LoRa Forwarders app"

  echo "Creating container 'waziup.wazigate-lora.forwarders' (Wazigate-LoRa App - Forwarders) ..."
  docker image load -i wazigate-lora-forwarders.tar
  rm wazigate-lora-forwarders.tar
  docker run -d --restart=unless-stopped --network=wazigate --name "waziup.wazigate-lora.forwarders" \
    -v "$PWD/apps/waziup.wazigate-lora/forwarders/:/root/conf" \
    -v "/var/run/dbus:/var/run/dbus" \
    -v "/sys/class/gpio:/sys/class/gpio" \
    -v "/dev:/dev" \
    -e "ENABLE_MULTI_SPI=1" \
    -e "ENABLE_MULTI_USB=1" \
    -e "ENABLE_SINGLE_SPI=1" \
    --device "/dev/ttyACM0:/dev/ttyACM0" \
    --privileged \
    --tty \
    --label "io.waziup.waziapp=waziup.wazigate-lora" \
    waziup/wazigate-lora-forwarders


  log 8 "Creating Wazigate-LoRa Redis app"

  echo "Creating container 'redis' (Wazigate-LoRa App - Redis) ..."
  docker image load -i redis.tar
  rm redis.tar
  docker run -d --restart=unless-stopped --network=wazigate --name redis \
    -v "redisdata:/data" \
    redis:6-alpine --appendonly yes --maxmemory 100mb --tcp-backlog 128


  log 9 "Creating Wazigate-LoRa PostgreSQL app"

  echo "Creating container 'postgresql' (Wazigate-LoRa App - PostgreSQL) ..."
  docker image load -i postgresql.tar
  rm postgresql.tar
  docker run -d --restart=unless-stopped --network=wazigate --name postgresql \
    -v "$PWD/apps/waziup.wazigate-lora/postgresql/initdb:/docker-entrypoint-initdb.d" \
    -v "postgresqldata:/var/lib/postgresql/data" \
    -e "POSTGRES_HOST_AUTH_METHOD=trust" \
    waziup/wazigate-postgresql


  log 10 "Creating Wazigate-LoRa ChirptStack Gateway Bridge app"

  echo "Creating container 'chirpstack-gateway-bridge' (Wazigate-LoRa App - ChirptStack Gateway Bridge) ..."
  docker image load -i chirpstack-gateway-bridge.tar
  rm chirpstack-gateway-bridge.tar
  docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-gateway-bridge \
    -v "$PWD/apps/waziup.wazigate-lora/chirpstack-gateway-bridge:/etc/chirpstack-gateway-bridge" \
    -p "1700:1700/udp" \
    --label "io.waziup.waziapp=waziup.wazigate-lora" \
    waziup/chirpstack-gateway-bridge:3.9.2


  log 11 "Creating Wazigate-LoRa ChirptStack Application Server app"

  echo "Creating container 'chirpstack-application-server' (Wazigate-LoRa App - ChirptStack Application Server) ..."
  docker image load -i chirpstack-application-server.tar
  rm chirpstack-application-server.tar
  docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-application-server \
    -v "$PWD/apps/waziup.wazigate-lora/chirpstack-application-server:/etc/chirpstack-application-server" \
    -p "8080:8080" \
    --label "io.waziup.waziapp=waziup.wazigate-lora" \
    waziup/chirpstack-application-server:3.13.2


  log 12 "Creating Wazigate-LoRa ChirptStack Network Server app"

  echo "Creating container 'chirpstack-network-server' (Wazigate-LoRa App - ChirptStack Network Server) ..."
  docker image load -i chirpstack-network-server.tar
  rm chirpstack-network-server.tar
  docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-network-server \
    -v "$PWD/apps/waziup.wazigate-lora/chirpstack-network-server:/etc/chirpstack-network-server" \
    --label "io.waziup.waziapp=waziup.wazigate-lora" \
    waziup/chirpstack-network-server:3.11.0


  log 13 "Creating Wazigate-LoRa app"

  echo "Creating container 'waziup.wazigate-lora' (Wazigate-LoRa App) ..."
  docker image load -i wazigate-lora.tar
  rm wazigate-lora.tar
  docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora \
    -v "$PWD/apps/waziup.wazigate-lora:/var/lib/waziapp" \
    --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
    --health-interval=10s \
    --label "io.waziup.waziapp=waziup.wazigate-lora" \
    waziup/wazigate-lora:$WAZIGATE_TAG
fi
