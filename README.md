# wazigate-gen

This tool will create Wazigate ISO images for Raspberry Pi. It is based on the [pi-gen](https://github.com/RPi-Distro/pi-gen) repository, the tool used to create Raspberry Pi OS images. **Please see the pi-gen README file for complete information.**

In stage 3 we will install WaziGate components on the image. WaziApps are base on Docker images, so you will also need to install [Docker](https://docs.docker.com/get-docker/) on your machine. The scripts will use Docker to pull some images from the Docker hub and place them inside the new OS. Stage 3 is the final stage, graphical stages are removed. The Wazigate library will be installed at `/var/lib/wazigate/`.

## Build

Here is a set of recommended values for the `config` file:
```
IMG_NAME              = 'WaziGate'
FIRST_USER_PASS       = 'loragateway'
TARGET_HOSTNAME       = 'wazigate'
PI_GEN_REPO           = 'https://github.com/Waziup/WaziGate-ISO-gen'
```

To start the compilation, type:
```
./build.sh
```

## Duplicate SD-Card

You now got the possibility to duplicate or clone your SD-Card. This is especially useful if you want to deploy several WaziGates, you initially setup one and then duplicate the SD-Card to deploy the other gateways. The WaziGate will recognize it and assigns another WaziGate-ID to the new device, it is ensured, that there aren't multiple gateways with the same (normally unique) IDs. The WaziGate-ID is dependent on the RPIs ethernet MAC address.
If you do not know how to accomplish this, follow this [guide](https://linuxhint.com/how-to-clone-a-raspberry-pi-sd-card/#:~:text=Insert%20an%20empty%20SD%20in,%E2%80%9CCopy%20to%20device%20box%E2%80%9D.) to learn more about the possibilities to duplicate your SD-Card.


