#!/bin/bash -e

DEFAULT_WAZIGATE_BRANCH="master"
if [ -z "$WAZIGATE_BRANCH" ]; then
	WAZIGATE_BRANCH=$DEFAULT_WAZIGATE_BRANCH
fi

DEFAULT_WAZIGATE_TAG="latest"
if [ -z "$WAZIGATE_TAG" ]; then
	WAZIGATE_TAG=$DEFAULT_WAZIGATE_TAG
fi

DEFAULT_WAZIGATE_REPO="https://github.com/Waziup/WaziGate.git"
if [ -z "$WAZIGATE_REPO" ]; then
	WAZIGATE_REPO=$DEFAULT_WAZIGATE_REPO
fi

# WAZIGATE_DIR=$ROOTFS_DIR/home/${FIRST_USER_NAME}/wazigate

################################################################################


WAZIGATE_DIR=$ROOTFS_DIR/var/lib/wazigate

# Download Wazigate Repo
# git clone -b $WAZIGATE_BRANCH --single-branch $WAZIGATE_REPO $WAZIGATE_DIR
cp -R files/wazigate $ROOTFS_DIR/var/lib

chmod +x $WAZIGATE_DIR/wazigate-host/wazigate-host
chmod +x $WAZIGATE_DIR/setup.sh
sed -i "s/^WAZIGATE_TAG.*/WAZIGATE_TAG=$WAZIGATE_TAG/g" $WAZIGATE_DIR/.env

################################################################################


# Install newer version for libseccomp2
echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a "$ROOTFS_DIR/etc/apt/sources.list.d/debian-backports.list"
on_chroot <<EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
apt-get update
apt-get install -y -qq --no-install-recommends -t buster-backports libseccomp2
EOF

################################################################################


if [ "${CLEAN}" = "1" ]; then
  rm -rf files/*.tar
fi

function save_docker_image {
  # Cleaning existing image
  if [ "${CLEAN}" = "1" ] && [ -f "files/$1.tar" ]; then
    rm -f "files/$1.tar";
  fi
  # Download Docker Image from Docker Hub
  if [ -f "files/$1.tar" ]; then
    echo "Using $1 docker image from $1.tar"
  else
    echo "Saving $2 to files/$1.tar ..."
    docker image save ${2%:*} -o files/$1.tar
    #sudo chmod 644 files/$1.tar # For debug
  fi

  # Copy Docker Images
  install -m 644 files/$1.tar "$WAZIGATE_DIR/"
}

function read_from_compose {
    # have to add a path
    declare -a IFS=$'' image_names=($(grep '^\s*image' docker-compose.yml | sed 's/image://'))
    #declare -a IFS=$' ' platform=($(grep '^\s*platform' docker-compose.yml | sed 's/platform://')) # use yq instead

    i=0
    # docker pull all images at once via docker-compose file
    docker-compose -f files/wazigate/docker-compose.yml pull

    for single_elemet in "${image_names[@]}"
    do
        full_name=$single_elemet
        # Delete tags
        striped_elemet=${single_elemet%:*}
        # Delete before "/"
        striped_elemet=${striped_elemet#*/}

        echo "Step: $i" "$striped_elemet" "$full_name" #"${platform[$i]}"
        save_docker_image "$striped_elemet" "$full_name"

        let "i += 1"
    done
}

read_from_compose

################################################################################
install -m 644 files/NetworkManager.conf "$ROOTFS_DIR/etc/NetworkManager/"

# Run setup.sh as systemd service on boot  
mv "$WAZIGATE_DIR/wazigate-setup.service" "$ROOTFS_DIR/etc/systemd/system"

# Run wazigate-host as systemd service on boot  
mv "$WAZIGATE_DIR/wazigate-host/wazigate-host" "$ROOTFS_DIR/usr/bin"
mv "$WAZIGATE_DIR/wazigate-host/wazigate-host.service" "$ROOTFS_DIR/etc/systemd/system"


# Enable Wazigate services
on_chroot <<EOF
systemctl enable wazigate-setup
systemctl enable wazigate-host
EOF

# 
cat <<EOT >> $ROOTFS_DIR/etc/sysctl.conf
###################################################################
# Change the kernel virtual memory accounting mode.
#   Values are:
#     0: heuristic overcommit (this is the default)
#     1: always overcommit, never check
#     2: always check, never overcommit
vm.overcommit_memory = 1
EOT

# Show text-ui on login
echo -e "sudo bash /var/lib/wazigate/wazigate-host/text-ui.sh" >> "$ROOTFS_DIR/home/$FIRST_USER_NAME/.profile"
