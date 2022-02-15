#!/bin/bash -e

log () {
  echo "Step $1/3: $2" > /tmp/wazigate-setup-step.txt
}

loadNRun () {
  ending=".tar"
  filename="$1$ending"

  # For debugging
  ########################################
  #docker image save "waziup/${name}" -o $1
  #docker rm -f "waziup.$name"
  ########################################

  if [ -f $filename ]; then
    echo "Creating container $1 from file: $filename"
    docker image load -i $filename
    rm $filename
    #docker-compose up -d $name # Now we can use docker-compose file
  else 
    echo "Compressed file $filename, of Container $1 does not exist"
  fi
}

readImageNames () {
  declare -a IFS=$'' image_names=($(grep '^\s*image' docker-compose.yml | sed 's/image://'))

  for single_elemet in "${image_names[@]}"
  do
    # Delete tags
    striped_elemet=${single_elemet%:*}
    # Delete before "/"
    striped_elemet=${striped_elemet#*/}

    loadNRun "$striped_elemet"
  done
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

sed -i "s/^WAZIGATE_ID.*/WAZIGATE_ID=$WAZIGATE_ID/g" .env

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
currentFullID=$(nmcli c show WAZIGATE-AP | grep "802-11-wireless.ssid" | sed 's/802-11-wireless.ssid://')
currentMAC=${currentFullID#*_}

if [ ! -f /etc/NetworkManager/system-connections/WAZIGATE_AP.nmconnection ]; then
  nmcli dev wifi hotspot ifname wlan0 con-name WAZIGATE-AP ssid $SSID password "loragateway"
  nmcli connection modify WAZIGATE-AP \
    connection.autoconnect true connection.autoconnect-priority -100 \
    802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared ipv6.method auto \
    wifi-sec.key-mgmt wpa-psk wifi-sec.proto wpa
  # using down/up instead of reapply because '802-11-wireless.band' can not be changed on the fly
  nmcli c down WAZIGATE-AP
  nmcli c up WAZIGATE-AP
elif [ $currentFullID =~ WAZIGATE_[A-Z0-9]{12}$ ]; then #johann
  nmcli connection modify WAZIGATE-AP \
    connection.autoconnect true connection.autoconnect-priority -100 \
    802-11-wireless.ssid=$SSID
elif [ "currentMAC" != "${SSID#*_}"]; then #felix
  nmcli connection modify WAZIGATE-AP \
    connection.autoconnect true connection.autoconnect-priority -100 \
    802-11-wireless.ssid=$SSID
fi

################################################################################

log 3 "Loading docker Iamges"

# Read from docker compose: load images
readImageNames
# Create containers
docker-compose up -d