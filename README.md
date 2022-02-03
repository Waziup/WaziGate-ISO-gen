# wazigate-gen

This tool will create Wazigate ISO images for Raspberry Pi. It is based on the [pi-gen](https://github.com/RPi-Distro/pi-gen) repository, the tool used to create Raspberry Pi OS images. **Please see the pi-gen README file for complete information.**

In stage 3 we will install WaziGate components on the image. WaziApps are base on Docker images, so you will also need to install [Docker](https://docs.docker.com/get-docker/) on your machine. The scripts will use Docker to pull some images from the Docker hub and place them inside the new OS. Stage 3 is the final stage, graphical stages are removed. The Wazigate library will be installed at `/var/lib/wazigate/`.

## Config

The configuration variables are the same than pi-gen, with the addition of:

 - WAZIGATE_TAG (default: latest): the tag to be used to pull the docker containers.
 - WAZIGATE_VERSION: the version of the WaziGate to display on the UI.


## Build

Here is a set of recommended values for the `config` file:
```
IMG_NAME              = 'WaziGate'
FIRST_USER_PASS       = 'loragateway'
TARGET_HOSTNAME       = 'wazigate'
PI_GEN_REPO           = 'https://github.com/Waziup/WaziGate-ISO-gen'
WAZIGATE_TAG          = 'latest'
WAZIGATE_VERSION      = 'v2'
```

To start the compilation, type:
```
./build.sh
```
