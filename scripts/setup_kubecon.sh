#!/bin/bash

if [ -z "$GOPATH" ]; then
	export GOPATH=/root/go
fi

install_kata(){
	ARCH=$(arch)
	sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/ /' > /etc/apt/sources.list.d/kata-containers.list"
	curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/Release.key | sudo apt-key add -
	sudo -E apt-get update
	sudo -E apt-get -y install kata-runtime kata-proxy kata-shim
}

install_docker(){
	sudo -E apt-get -y install apt-transport-https ca-certificates software-properties-common
	curl -sL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	arch=$(dpkg --print-architecture)
	sudo -E add-apt-repository "deb [arch=${arch}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo -E apt-get update
	sudo -E apt-get -y install docker-ce
}

install_essential(){
	sudo apt-get update
	sudo apt-get install wget golang-1.10-go libseccomp-dev btrfs-tools git -y
}

install_shimv2(){
	go get github.com/kata-containers/runtime
	pushd $GOPATH/src/github.com/kata-containers/runtime
	git remote add hyper https://github.com/hyperhq/kata-runtime
	git fetch hyper
	git checkout -b shimv2 hyper/shimv2
	make 
	sudo -E PATH=$PATH make install
	popd

	sed -i 's/image =/#image =/' /usr/share/defaults/kata-containers/configuration.toml
}

install_containerd(){
	go get github.com/containerd/containerd
	pushd $GOPATH/src/github.com/containerd/containerd
	make
	sudo -E PATH=$PATH make install
	popd
}

install_cni(){
	go get github.com/containernetworking/plugins
	pushd $GOPATH/src/github.com/containernetworking/plugins
	./build.sh
	mkdir /opt/cni
	cp -r bin /opt/cni/
	popd
}

install_cri(){
	go get github.com/kubernetes-incubator/cri-tools
	pushd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
	make
	make install
	popd
}

install_gvisor(){
        wget https://storage.googleapis.com/gvisor/releases/nightly/latest/runsc
        chmod +x runsc
        sudo mv runsc /usr/local/bin/
}

export PATH=$PATH:/usr/lib/go-1.10/bin

install_essential || 
if [ $? != 0 ]; then
	echo "Error: Installing the essential pkgs failed."
	exit 1
fi

install_kata
if [ $? != 0 ]; then
	echo "Error: installing kata failed"
	exit 1
fi

install_containerd
if [ $? != 0 ]; then
        echo "Error: installing containerd failed"
        exit 1
fi 

#install_cni
#if [ $? != 0 ]; then
#        echo "Error: installing cni failed"
#        exit 1
#fi

install_shimv2
if [ $? != 0 ]; then
        echo "Error: installing shimv2 failed"
        exit 1
fi

install_cri
if [ $? != 0 ]; then
        echo "Error: installing cri failed"
        exit 1
fi

#install_docker
#if [ $? != 0 ]; then
#        echo "Error: installing docker failed"
#        exit 1
#fi

#install_gvisor
#if [ $? != 0 ]; then
#        echo "Error: installing gvisor failed"
#        exit 1
#fi

scripDir=`dirname $0`
scripDir=`realpath $scripDir`
prjDir=`dirname $scripDir`
dataDir="$prjDir/data"

echo "Deploy the containerd configure file"
sudo mkdir /etc/containerd/
cp $dataDir/config.toml /etc/containerd/

#echo "Deploy cni configure file"
#sudo mkdir -p /etc/cni/net.d
#sudo cp $dataDir/10-mynet.conf  /etc/cni/net.d/
#

echo "Deploy crictl configure file"
sudo cp $dataDir/crictl.yaml /etc/

