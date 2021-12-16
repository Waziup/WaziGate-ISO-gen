# wazigate-gen

This tool will create Wazigate ISO images for Raspberry Pi. It is based on the [pi-gen](https://github.com/RPi-Distro/pi-gen) repository, the tool used to create Raspberry Pi OS images. **Please see the pi-gen README file for complete information.**

In stage 3 we will install WaziGate components on the image. WaziApps are base on Docker images, so you will also need to install [Docker](https://docs.docker.com/get-docker/) on your machine. The scripts will use Docker to pull some images from the Docker hub and place them inside the new OS. Stage 3 is the final stage, graphical stages are removed. The Wazigate library will be installed at `/var/lib/wazigate/`.

## Build

The configuration is essentially the same as pi-gen. Here is a set of recommended values for the `config` file:
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
