#!/bin/bash
[ ! $1 ] && echo "Architecture not found, please add raspberrypi model ( 0 | 1 | 2 | 3 | 3x64 )" && exit
pushd $(dirname "$0")
. ../../functions.sh

build_env $1

rm -rf rpi* *-tmp

[ "$RPI_MODEL" = "1" ] || [ "$RPI_MODEL" = "0" ] && RPI_TYPE="1"
[ "$RPI_MODEL" = "2" ] || [ "$RPI_MODEL" = "3" ] && RPI_TYPE="2"
[ "$RPI_MODEL" = "3x64" ] && RPI_TYPE="3"

RESET=true

#Pull source
URL="https://github.com/raspberrypi/linux"
pull_source "${URL}" "linux" "rpi-4.14.y"

if [ -d "linux" ]; then

   export EMAIL="cyr-ius@ipocus.net"
   export DEBFULLNAME="Cyr-ius Thozz"
   export KDEB_CHANGELOG_DIST="stretch"
   export KBUILD_DEBARCH=$RELEASE_ARCH

   KERNEL_THREADS=$(grep -c processor /proc/cpuinfo)

   # Clean the kernel sources
   make -j4 -C "linux" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}-" mrproper

   # Load default raspberry kernel configuration
   make -j4 -C "linux" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}-" "${KERNEL_DEFCONFIG}"
  
   # Cross compile kernel and modules
   make -j4 deb-pkg  -C "linux" -j$KERNEL_THREADS ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}-" "${KERNEL_BIN_IMAGE}" modules dtbs && echo "Make and package successful" || echo "Warning while make kernel"

   
   # Create metapackage
   release=`cat "linux/include/config/kernel.release"`
   revision=$(cat linux/.version)
   version=$release-$revision

   cp -r files-firmware files-firmware-tmp
   cd files-firmware-tmp
   sed "s/rpi-firmware/rpi$RPI_TYPE-firmware/g" -i debian/changelog
   sed "s/rpi-firmware/rpi$RPI_TYPE-firmware/g" -i debian/control
   sed '/Depends/d' -i debian/control
   echo "Depends: \${misc:Depends}, rpi$RPI_TYPE-bootloader (=${version}), rpi$RPI_TYPE-userland (=${version}), linux-image-${release} (=${version}), linux-libc-dev (>=${version})" >> debian/control
   fix_version $version
   fix_distribution "stretch"
   dpkg-buildpackage -B -us -uc -a$RELEASE_ARCH
   cd ..
fi

#Pull source
URL="https://github.com/raspberrypi/firmware"
pull_source "${URL}" "firmware" "next"

if [ -d "firmware" ]; then

#  Build packages
cp -r files files-tmp
cd files-tmp
sed "s/rpi-/rpi$RPI_TYPE-/g" -i debian/changelog
sed "s/rpi-/rpi$RPI_TYPE-/g" -i debian/control
sed "s/(=0)/(=$version)/g" -i debian/control
sed  "s/Architecture: all/Architecture: $RELEASE_ARCH/g" -i debian/control
echo "override_dh_strip:" >> debian/rules
echo "override_dh_shlibdeps:" >> debian/rules
rename "s/rpi-/rpi$RPI_TYPE-/" debian/rpi-*
fix_version $version
fix_distribution "stretch"
dpkg-buildpackage -B -us -uc -a$RELEASE_ARCH
cd ..

mkdir -p ../../packages
mv rpi* linux-* ../../packages

rm -rf *-tmp

else
 echo "Firmware folder not exist"
fi
popd
