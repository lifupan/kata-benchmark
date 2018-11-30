#!/bin/bash

install_kata(){
        ARCH=$(arch)
        sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/ /' > /etc/apt/sources.list.d/kata-containers.list"
        curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/Release.key | sudo apt-key add -
        sudo -E apt-get update
        sudo -E apt-get -y install kata-runtime kata-proxy kata-shim
}

install_essential(){
        sudo apt-get update
        sudo apt-get install libseccomp-dev btrfs-tools git -y
}

install_shimv2(){
        go get github.com/kata-containers/runtime
        pushd $GOPATH/src/github.com/kata-containers/runtime
        make
        sudo -E PATH=$PATH make install
        popd

        sed -i 's/image =/#image =/' /usr/share/defaults/kata-containers/configuration.toml
}

install_cni(){
        go get github.com/containernetworking/plugins
        pushd $GOPATH/src/github.com/containernetworking/plugins
        ./build_linux.sh
        mkdir /opt/cni
        cp -r bin /opt/cni/
        popd
}

install_essential
if [ $? != 0 ]; then
        echo "Error: Installing the essential pkgs failed."
        exit 1
fi

echo "Deploy cni configure file"
if [ ! -d /etc/cni/net.d ]; then
	sudo mkdir -p /etc/cni/net.d
	cat >/etc/cni/net.d/10-mynet.conf <<EOF
{
	"cniVersion": "0.2.0",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "172.19.0.0/24",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}
EOF
fi

sudo systemctl stop docker

install_kata
if [ $? != 0 ]; then
        echo "Error: installing kata failed"
        exit 1
fi

install_cni
if [ $? != 0 ]; then
        echo "Error: installing cni failed"
        exit 1
fi

install_shimv2
if [ $? != 0 ]; then
        echo "Error: installing shimv2 failed"
        exit 1
fi

go get github.com/containerd/cri

if [ ! -d $GOPATH/src/k8s.io/kubernetes ]; then
	mkdir -p $GOPATH/src/k8s.io/kubernetes
	git clone https://github.com/kubernetes/kubernetes $GOPATH/src/k8s.io/kubernetes
fi

pushd $GOPATH/src/github.com/containerd/cri
make

tempdir=`mktemp -d`
cat >$tempdir/config.toml <<EOF
[plugins]
  [plugins.cri]
    sandbox_image = "mirrorgooglecontainers/pause-amd64:3.1"
    [plugins.cri.containerd]
      [plugins.cri.containerd.default_runtime]
	runtime_type = "io.containerd.kata.v2"
[plugins.cri.cni]
    # conf_dir is the directory in which the admin places a CNI conf.
    conf_dir = "/etc/cni/net.d"
EOF


./hack/test-e2e-node.sh
popd

rm -rf $tempdir
