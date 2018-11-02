#!/bin/bash

ID=""
JOBS=1
RUNTIME="runc"
KVM=false

scriptDir=`dirname $0`
scriptDir=`realpath $scriptDir`
prjDir="$scriptDir/../"
if [ ! -d $prjDir/fioLogs ]; then
        mkdir $prjDir/../fioLogs
fi

VOLUME=$prjDir

cleanup(){
	if [ "$ID" != "" ]; then
		sudo docker stop $ID
	fi
	systemctl stop docker
}

usage(){
	echo "Usage: $0 -j <num jobs> -r <runtime type> -k"
	echo "runtime type can be kata, runsc or runc"
	echo "runc will be the fefault choice"
	echo "-k" is used to enable kvm for runsc.
	exit 0
}

if [ "X$1" == "X" ]; then
	usage
fi

while getopts "j:r:v:k" arg #选项后面的冒号表示该选项需要参数
do
        case $arg in
             j)
		JOBS=$OPTARG
                ;;
             r)
                RUNTIME=$OPTARG
                ;;
	     v)
		VOLUME=$OPTARG
		;;
	     k)
		KVM=true
		;;
             ?)  #当有不认识的选项的时候arg为?
            echo "unkonw argument"
        exit 1
        ;;
        esac
done

if [ "$RUNTIME" != "kata" -a "$RUNTIME" != "runsc" -a "$RUNTIME" != "runc" ]; then
	echo "Error: runtime type isn't supported"
	usage
fi

if [ $KVM ]; then
	cat >/etc/docker/daemon.json <<EOF
{
  "default-runtime": "runc",
  "runtimes": {
    "kata": {
      "path": "/usr/local/bin/kata-runtime"
    },
    "runsc": {
      "path": "/usr/local/bin/runsc"
      "runtimeArgs": [
                "--platform=kvm"
            ]
    }
  }
}
EOF
else
	cat >/etc/docker/daemon.json <<EOF
{
  "default-runtime": "runc",
  "runtimes": {
    "kata": {
      "path": "/usr/local/bin/kata-runtime"
    },
    "runsc": {
      "path": "/usr/local/bin/runsc"
    }
  }
}
EOF     
fi	
echo "start docker daemon"
sudo systemctl start docker

scriptDir=`dirname $0`
scriptDir=`realpath $scriptDir`
prjDir="$scriptDir/../"
if [ ! -d $prjDir/fioLogs/$runtime ]; then
        mkdir -p $prjDir/../fioLogs/$runtime
fi

ID=`sudo docker run -dt --rm --runtime $RUNTIME -v $VOLUME:/test ubuntu`

if [ "$ID" == "" ]; then
	echo "Error: failed to start container"
	cleanup
	exit 1
fi

sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-4k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-4k-write.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-128k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-128k-write.fio

EXEC="sudo docker exec -ti $ID"

$EXEC apt-get update
$EXEC apt-get install fio -y
$EXEC fio --output=/test/fioLogs/$runtime/fio-4k-read.log /test/fio-rand-4k-read.fio
if [ $? != 0 ]; then
	cleanup
	exit 1
fi
$EXEC fio --output=/test/fioLogs/$runtime/fio-4k-write.log /test/fio-rand-4k-write.fio
if [ $? != 0 ]; then
	cleanup
        exit 1
fi

$EXEC fio --output=/test/fioLogs/$runtime/fio-128k-read.log /test/fio-rand-128k-read.fio
if [ $? != 0 ]; then
        cleanup
        exit 1
fi
$EXEC fio --output=/test/fioLogs/$runtime/fio-128k-write.log /test/fio-rand-128k-write.fio
cleanup
