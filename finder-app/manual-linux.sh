#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    # remove conflicting definition of yylloc
    sed -i '/YYLTYPE yylloc/d' scripts/dtc/dtc-lexer.l

    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j32 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Adding the Image in outdir"

# TODO: Copy Image to target directory
cp arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs
cd "$OUTDIR/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr/bin usr/lib usr/sbin var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    BUSYBOX_RELEASE_VERSION=$(echo "${BUSYBOX_VERSION}" | tr _ .)
    wget -O busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2 \
         https://busybox.net/downloads/busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2
    wget -O busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2.sha256 \
         https://busybox.net/downloads/busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2.sha256
    if ! sha256sum --check busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2.sha256
    then
        echo "busybox tarball checksum verification failed!"
        exit 1
    fi
    mkdir busybox
    tar xvjf busybox-${BUSYBOX_RELEASE_VERSION}.tar.bz2 -C busybox --strip-components 1
    cd busybox
    # TODO:  Configure busybox
    make distclean
    make defconfig
    sed -i 's/CONFIG_TC=y/CONFIG_TC=n/' ${OUTDIR}/busybox/.config
else
    cd busybox
fi

# TODO: Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

# TODO: Add library dependencies to rootfs
echo "Library dependencies"

SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# programmatically parse the output of readelf in a way that is compatible with
# more than one cross-compiler version, then copy the libraries that are 
# detected as necessary

# Interpreter
INTERPRETER=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | \
    grep "program interpreter" | tr -s ' ]' '[' | cut -d '[' -f5)
cp -aL ${SYSROOT}${INTERPRETER} ${OUTDIR}/rootfs/$(dirname ${INTERPRETER})/

# Shared libraries
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" | \
    xargs -n1 echo | tr -s '[]' '[' | cut -d '[' -f2 | awk 'NR % 5 == 0' | \
    xargs -I {} \
    cp -aL ${SYSROOT}/lib64/{} ${OUTDIR}/rootfs/lib64

# TODO: Make device nodes
cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# TODO: Clean and build the writer utility
cd ${FINDER_APP_DIR}
make clean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}

cp writer ${OUTDIR}/rootfs/home/

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
mkdir -p ${OUTDIR}/rootfs/home/conf
cp finder.sh finder-test.sh ${OUTDIR}/rootfs/home/
cp conf/username.txt conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/

# TODO: Chown the root directory
cd ${OUTDIR}/rootfs
sudo chown -R root:root *

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ../initramfs.cpio
cd ..
gzip initramfs.cpio
