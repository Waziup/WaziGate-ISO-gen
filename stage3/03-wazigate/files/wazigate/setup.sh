#!/bin/bash -e

log () {
  echo "Step $1/12: $2" > /tmp/wazigate-setup-step.txt
}

loadNRun () {
  # delete file ending
  name=${1%.*}

  # For debugging
  ########################################
  #docker image save "waziup/${name}" -o $1
  #docker rm -f "waziup.$name"
  ########################################

  if [ -f $1 ]; then
    echo "Creating container $name"
    docker image load -i $1
    rm $1
    docker-compose up -d $name
  else 
      echo "Compressed file $1, of Container $name does not exist"
  fi
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
export WAZIGATE_ID=${WAZIGATE_ID//:}

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

log 2 "Configuring Access Point"

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

log 3 "Creating Wazigate-Mongo app"
loadNRun "wazigate-mongo.tar"

log 4 "Creating Wazigate-Edge app"
loadNRun "wazigate-edge.tar"

log 5 "Creating Wazigate-System app"
loadNRun "wazigate-system.tar"

################################################################################

log 6 "Creating Wazigate-LoRa Forwarders app"
loadNRun "wazigate-lora-forwarders.tar"

log 7 "Creating Wazigate-LoRa Redis app"
loadNRun "redis.tar"

log 8 "Creating Wazigate-LoRa PostgreSQL app"
loadNRun "postgresql.tar"

log 9 "Creating Wazigate-LoRa ChirptStack Gateway Bridge app"
loadNRun "chirpstack-gateway-bridge.tar"

log 10 "Creating Wazigate-LoRa ChirptStack Application Server app"
loadNRun "chirpstack-application-server.tar"

log 11 "Creating Wazigate-LoRa ChirptStack Network Server app"
loadNRun "chirpstack-network-server.tar"

log 12 "Creating Wazigate-LoRa app"
loadNRun "wazigate-lora.tar"