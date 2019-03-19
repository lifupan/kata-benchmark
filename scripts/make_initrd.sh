#!/bin/sh

export GOPATH="/home/fupan/go"

export ROOTFS_DIR="${GOPATH}/src/github.com/kata-containers/osbuilder/rootfs-builder/rootfs"
sudo rm -rf ${ROOTFS_DIR}
cd $GOPATH/src/github.com/kata-containers/osbuilder/rootfs-builder
sudo -E GOPATH=$GOPATH AGENT_INIT=yes USE_DOCKER=true ./rootfs.sh "alpine"

sudo install -o root -g root -m 0550 -T ../../agent/kata-agent ${ROOTFS_DIR}/sbin/init

cd $GOPATH/src/github.com/kata-containers/osbuilder/initrd-builder
script -fec 'sudo -E AGENT_INIT=yes USE_DOCKER=true ./initrd_builder.sh ${ROOTFS_DIR}'

commit=$(git log --format=%h -1 HEAD)
date=$(date +%Y-%m-%d-%T.%N%z)
image="kata-containers-initrd-${date}-${commit}"
sudo install -o root -g root -m 0640 -D kata-containers-initrd.img "/usr/share/kata-containers/${image}"
(cd /usr/share/kata-containers && sudo ln -sf "$image" kata-containers-initrd.img)
