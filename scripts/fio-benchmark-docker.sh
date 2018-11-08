#!/bin/bash
ID=""
JOBS=1
RUNTIME="runc"
KVM=0
HOST=0
scriptDir=`dirname $0`
scriptDir=`realpath $scriptDir`
prjDir="$scriptDir/../"
if [ ! -d $prjDir/fioLogs ]; then
        mkdir $prjDir/fioLogs
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
	echo "-v" is used to add volume
	exit 0
}

if [ "X$1" == "X" ]; then
	usage
fi

while getopts "j:r:v:kh" arg #选项后面的冒号表示该选项需要参数
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
		KVM=1
		;;
	     h)
		HOST=1
		;;
             ?)  #当有不认识的选项的时候arg为?
            echo "unkonw argument"
        exit 1
        ;;
        esac
done

if [ "$RUNTIME" != "kata-runtime" -a "$RUNTIME" != "runsc" -a "$RUNTIME" != "runc" ]; then
	echo "Error: runtime type isn't supported"
	usage
fi

if [ $KVM == 1 ]; then

cat >/etc/docker/daemon.json <<EOF
{
  "default-runtime": "runc",
  "runtimes": {
    "kata-runtime": {
      "path": "/usr/local/bin/kata-runtime"
    },
    "runsc": {
      "path": "/usr/local/bin/runsc",
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
    "kata-runtime": {
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

if [ ! -d $prjDir/fioLogs/$RUNTIME ]; then
        mkdir -p $prjDir/fioLogs/$RUNTIME
fi

cpu_mem=""
if [ $RUNTIME != "kata-runtime" ]; then
	cpu_mem="--cpus 8 -m 8G"
fi

ID=`sudo docker run $cpu_mem -dt --rm --runtime $RUNTIME -v $VOLUME:/test ubuntu`

if [ "$ID" == "" ]; then
	echo "Error: failed to start container"
	cleanup
	exit 1
fi

sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-4k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-4k-write.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-128k-read.fio
sed -i "s/^numjobs=.*$/numjobs=$JOBS/" $scriptDir/../fio-rand-128k-write.fio

prefix=""
if [ $HOST == 0 ]; then
	EXEC="sudo docker exec -ti $ID"
	prefix="/test/"
else
	EXEC="sudo"
	RUNTIME="host"
	prefix="$VOLUME"
fi

sed -i "s#^filename=.*\$#filename=${prefix}/fio-rand-read#" $scriptDir/../fio-rand-4k-read.fio
sed -i "s#^filename=.*\$#filename=${prefix}/fio-rand-read#" $scriptDir/../fio-rand-4k-write.fio
sed -i "s#^filename=.*\$#filename=${prefix}/fio-rand-read#" $scriptDir/../fio-rand-128k-read.fio
sed -i "s#^filename=.*\$#filename=${prefix}/fio-rand-read#" $scriptDir/../fio-rand-128k-write.fio

APPENDIX="rootfs"
PREFIX=`dirname $VOLUME`

if [ "$PREFIX" == "/dev" ]; then
        APPENDIX="passthrough"
        dir=`mktemp -d`
        mount $VOLUME $dir
        cp -r $prjDir/*.fio $dir/
        mkdir -p $dir/fioLogs/$RUNTIME
        umount $VOLUME
        rm -rf $dir
else
	cp -r $prjDir/*.fio $VOLUME/
fi

$EXEC apt-get update
$EXEC apt-get install fio -y
$EXEC mkdir -p ${prefix}/fioLogs/$RUNTIME
$EXEC fio --output=${prefix}/fioLogs/$RUNTIME/fio-4k-read-$APPENDIX.log ${prefix}/fio-rand-4k-read.fio
if [ $? != 0 ]; then
	cleanup
	exit 1
fi
$EXEC fio --output=${prefix}/fioLogs/$RUNTIME/fio-4k-write-$APPENDIX.log ${prefix}/fio-rand-4k-write.fio
if [ $? != 0 ]; then
	cleanup
        exit 1
fi

$EXEC fio --output=${prefix}/fioLogs/$RUNTIME/fio-128k-read-$APPENDIX.log ${prefix}/fio-rand-128k-read.fio
if [ $? != 0 ]; then
        cleanup
        exit 1
fi
$EXEC fio --output=${prefix}/fioLogs/$RUNTIME/fio-128k-write-$APPENDIX.log ${prefix}/fio-rand-128k-write.fio
cleanup
