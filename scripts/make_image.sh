#!/bin/sh
export GOPATH="/home/fupan/go"

export ROOTFS_DIR="${GOPATH}/src/github.com/kata-containers/osbuilder/rootfs-builder/rootfs"
sudo rm -rf ${ROOTFS_DIR}
cd $GOPATH/src/github.com/kata-containers/osbuilder/rootfs-builder

script -fec 'sudo -E GOPATH=$GOPATH USE_DOCKER=true SECCOMP=no ./rootfs.sh "centos"'


#sudo install -o root -g root -m 0550 -t ${ROOTFS_DIR}/bin /home/fupan/rust_prj/rust-agent/target/x86_64-unknown-linux-musl/debug/kata-agent 
sudo cp /home/fupan/rust_prj/rust-agent/target/x86_64-unknown-linux-musl/debug/kata-agent ${ROOTFS_DIR}/bin/
sudo install -o root -g root -m 0440 ../../agent/kata-agent.service ${ROOTFS_DIR}/usr/lib/systemd/system/
sudo install -o root -g root -m 0440 ../../agent/kata-containers.target ${ROOTFS_DIR}/usr/lib/systemd/system/

cd $GOPATH/src/github.com/kata-containers/osbuilder/image-builder
script -fec 'sudo -E USE_DOCKER=true ./image_builder.sh ${ROOTFS_DIR}'

commit=$(git log --format=%h -1 HEAD)
date=$(date +%Y-%m-%d-%T.%N%z)
image="kata-containers-${date}-${commit}"
sudo install -o root -g root -m 0640 -D kata-containers.img "/usr/share/kata-containers/${image}"
(cd /usr/share/kata-containers && sudo ln -sf "$image" kata-containers.img)

