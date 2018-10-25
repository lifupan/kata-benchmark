#!/bin/bash

pod=""
c=""

cleanup(){
	if [ "$pod" != "" ]; then
		crictl stopp $pod; crictl rmp $pod
	fi
	killall containerd
}

echo "start containerd"
sudo containerd --config /etc/containerd/config.toml >/dev/null 2>&1 &

pod=`sudo crictl runp  example-pod.json`

if [ "$pod" == "" ]; then
	echo "Error: failed to start pod"
	cleanup
	exit 1
fi

c=`sudo crictl create $pod ubuntu-container.json example-pod.json`
if [ "$c" == "" ]; then
        echo "Error: failed to create container"
	cleanup
        exit 1
fi

sudo crictl start $c
if [ $? != 0 ]; then
	echo "Start container $c failed"
	cleanup
	exit 1
fi

scriptDir=`dirname $0`
scriptDir=`realpath $scriptDir`
if [ ! -d $scriptDir/../fioLogs ]; then
	mkdir $scriptDir/../fioLogs
fi

sudo crictl exec -ti $c apt-get update
sudo crictl exec -ti $c apt-get install fio -y
sudo crictl exec -ti $c fio --output=/test/fioLogs/fio-4k-read.log /test/fio-rand-4k-read.fio

cleanup
