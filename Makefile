# lib name, version
URL_KERNEL=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-4.14.y
URL_FIRMWARE=https://github.com/raspberrypi/firmware
FIRMWARE_BRANCH=next
EMAIL=cyr-ius@ipocus.net
DEBFULLNAME=Cyr-ius Thozz
KDEB_CHANGELOG_DIST?=stretch

NUMCPUS=$(shell grep -c '^processor' /proc/cpuinfo)

ifeq ($(RPI_MODEL),rbp1)
	MODEL=1
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcmrpi_defconfig
	KBUILD_DEBARCH=armhf
	CROSS_COMPILE=arm-linux-gnueabihf
endif

ifeq ($(RPI_MODEL),rbp2)
	MODEL=2
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcm2709_defconfig
	KBUILD_DEBARCH=armhf
	CROSS_COMPILE=arm-linux-gnueabihf
endif

ifeq ($(RPI_MODEL),rbp3)
	MODEL=3
	ARCH=arm64
	KERNEL_BIN_IMAGE=Image
	KERNEL_DEFCONFIG=bcmrpi3_defconfig
	KBUILD_DEBARCH=arm64
	CROSS_COMPILE=aarch64-linux-gnu
endif

export KBUILD_DEBARCH , KDEB_CHANGELOG_DIST , RPI_MODEL , DEBFULLNAME , EMAIL , MODEL

all:.make-linux

rbp%:
	RPI_MODEL=$@ $(MAKE) package

.prep-files:.prep-linux
	rm -f debian/control debian/changelog
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	rename s/rpi-/rpi$(MODEL)-/ debian/rpi-*
	sed s/#MODEL#/$(MODEL)/ debian/control.in > debian/control
	dch --create --distribution $(KDEB_CHANGELOG_DIST) --package "rpi$(MODEL)-userland" "Create userland for Raspberry Pi $(MODEL)" --newversion $(shell make -C linux/ kernelversion | grep -v "make")

.prep-firmware:
	@if  [ ! -d firmware ];then \
		echo "Load firmware...";\
		git clone $(URL_FIRMWARE) --depth=1 -b $(FIRMWARE_BRANCH); \
	else \
		echo "Clean firmware repository...";\
		git -C firmware clean -xfdd; \
		git -C firmware checkout -q -- *; \
		echo "Update firmware repository...";\
		git -C firmware pull; \
	fi
	
.prep-linux:.prep-firmware
	@if  [ ! -d linux ];then \
		echo "Load linux kernel...";\
		git clone $(URL_KERNEL) --depth=1 -b $(KERNEL_BRANCH); \
	else \
		echo "Clean linux repository...";\
		git -C linux clean -xfdd;\
		git -C linux checkout -q -- *;\
		echo "Update linux repository...";\
		git -C linux pull; \
	fi

.make-linux:.prep-linux
	- make -C linux ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" mrproper
	- make -C linux ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_DEFCONFIG)
	- make -C linux -j$(NUMCPUS) ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_BIN_IMAGE) modules dtbs
	- make -C linux -j$(NUMCPUS) ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_BIN_IMAGE) bindeb-pkg
	mv linux-* ..

package:.prep-files
	dpkg-buildpackage -us -uc -B -a$(KBUILD_DEBARCH)
	rm -f debian/control debian/changelog
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*

reset:
	debclean
	rm -f debian/control debian/changelog
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	rm -rf linux firmware

