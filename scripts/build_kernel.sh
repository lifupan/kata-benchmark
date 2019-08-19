#/bin/bash
set -x
go get github.com/kata-containers/tests
cd $GOPATH/src/github.com/kata-containers/tests/.ci
kernel_arch="$(./kata-arch.sh)"
kernel_dir="$(./kata-arch.sh --kernel)"
tmpdir="$(mktemp -d)"
pushd "$tmpdir"
curl -L https://raw.githubusercontent.com/kata-containers/packaging/master/kernel/configs/${kernel_dir}_kata_kvm_4.14.x -o .config
kernel_version=$(grep "Linux/[${kernel_arch}]*" .config | cut -d' ' -f3 | tail -1)
kernel_tar_file="linux-${kernel_version}.tar.xz"
kernel_url="https://cdn.kernel.org/pub/linux/kernel/v$(echo $kernel_version | cut -f1 -d.).x/${kernel_tar_file}"
#curl -LOk ${kernel_url}
cp /home/fupan/go/src/github.com/lifupan/kata-benchmark/${kernel_tar_file} ./ 
tar -xf ${kernel_tar_file}
mv .config "linux-${kernel_version}"
pushd "linux-${kernel_version}"
curl -L https://raw.githubusercontent.com/kata-containers/packaging/master/kernel/patches/0001-NO-UPSTREAM-9P-always-use-cached-inode-to-fill-in-v9.patch | patch -p1
curl -L https://raw.githubusercontent.com/kata-containers/packaging/master/kernel/patches/0002-Compile-in-evged-always.patch | patch -p1
make ARCH=${kernel_dir} -j$(nproc)
kata_kernel_dir="/usr/share/kata-containers"
kata_vmlinuz="${kata_kernel_dir}/kata-vmlinuz-${kernel_version}.container"
case $kernel_arch in ppc64le) kernel_path="./vmlinux";; aarch64) kernel_path="arch/arm64/boot/Image";; *) kernel_path="arch/${kernel_arch}/boot/bzImage";; esac
kernel_file="$(realpath $kernel_path)"
sudo install -o root -g root -m 0755 -D "${kernel_file}" "${kata_vmlinuz}"
sudo ln -sf "${kata_vmlinuz}" "${kata_kernel_dir}/vmlinuz.container"
kata_vmlinux="${kata_kernel_dir}/kata-vmlinux-${kernel_version}"
sudo install -o root -g root -m 0755 -D "$(realpath vmlinux)" "${kata_vmlinux}"
sudo ln -sf "${kata_vmlinux}" "${kata_kernel_dir}/vmlinux.container"
popd
popd
rm -rf "${tmpdir}"
