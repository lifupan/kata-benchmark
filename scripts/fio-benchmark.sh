#!/bin/bash

export GOPATH=/root/go

pod=""
c=""
threads=1

cleanup(){
	if [ "$pod" != "" ]; then
		crictl stopp $pod; crictl rmp $pod
	fi
	killall containerd
}

usage(){
	echo "Usage: $0 [numjobs]"
	exit 0
}

#if [ "$1" == '--help' || "$1" == '-h' ]; then
#	usage()
#fi

if [ "$1" != "" ]; then
	threads=$1
fi

echo "start containerd"
sudo containerd --config /etc/containerd/config.toml >/dev/null 2>&1 &

sudo crictl pull ubuntu:latest

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

sed -i "s/^numjobs=.*$/numjobs=$threads/" $scriptDir/../fio-rand-4k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$threads/" $scriptDir/../fio-rand-4k-write.fio
sed -i "s/^numjobs=.*$/numjobs=$threads/" $scriptDir/../fio-rand-128k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$threads/" $scriptDir/../fio-rand-128k-write.fio

sudo crictl exec -ti $c apt-get update
sudo crictl exec -ti $c apt-get install fio -y
sudo crictl exec -ti $c fio --output=/test/fioLogs/fio-4k-read.log /test/fio-rand-4k-read.fio
sudo crictl exec -ti $c fio --output=/test/fioLogs/fio-4k-write.log /test/fio-rand-4k-write.fio
sudo crictl exec -ti $c fio --output=/test/fioLogs/fio-128k-read.log /test/fio-rand-128k-read.fio
sudo crictl exec -ti $c fio --output=/test/fioLogs/fio-128k-write.log /test/fio-rand-128k-write.fio

cleanup
