# lib name, version
URL_KERNEL=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-4.14.y
URL_FIRMWARE=https://github.com/raspberrypi/firmware
FIRMWARE_BRANCH=next
EMAIL=cyr-ius@ipocus.net
DEBFULLNAME=Cyr-ius Thozz
KDEB_CHANGELOG_DIST=stretch

NUMCPUS=$(shell grep -c '^processor' /proc/cpuinfo)
RPI_MODEL?=2

ifeq ($(RPI_MODEL),1)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcmrpi_defconfig
	KBUILD_DEBARCH=armhf
	CROSS_COMPILE=arm-linux-gnueabihf
endif

ifeq ($(RPI_MODEL),2)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcm2709_defconfig
	KBUILD_DEBARCH=armhf
	CROSS_COMPILE=arm-linux-gnueabihf
endif

ifeq ($(RPI_MODEL),3)
	ARCH=arm64
	KERNEL_BIN_IMAGE=Image
	KERNEL_DEFCONFIG=bcmrpi3_defconfig
	KBUILD_DEBARCH=arm64
	CROSS_COMPILE=arch64-linux-gnu
endif

export KBUILD_DEBARCH , KDEB_CHANGELOG_DIST , RPI_MODEL , DEBFULLNAME , EMAIL

all:.make-linux

rbp1:
	RPI_MODEL=1 $(MAKE) package

rbp2:
	RPI_MODEL=2 $(MAKE) package

rbp3:
	RPI_MODEL=3 $(MAKE) package

.prep-files:.prep-linux
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	rename s/rpi-/rpi$(RPI_MODEL)-/ debian/rpi-*
	sed s/rpi-/rpi$(RPI_MODEL)-/ -i debian/control
	rm -f debian/changelog
	dch --create --distribution $(KDEB_CHANGELOG_DIST) --package "rpi$(RPI_MODEL)-userland" "Create userland for Raspberry Pi $(RPI_MODEL)" --newversion $(KERNEL_VERSION)

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
		git -C linux pull;\
	fi
	$(eval KERNEL_VERSION=$(shell make -C linux/ kernelversion | grep -v "make"))

.make-linux:.prep-linux
	- make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" mrproper
	- make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_DEFCONFIG)
	- make -j$(NUMCPUS) deb-pkg -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_BIN_IMAGE) modules dtbs

package:.prep-files
	dpkg-buildpackage -us -uc -B -a$(KBUILD_DEBARCH)
	mv linux-* ..
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	rm -f debian/changelog

reset:
	debclean
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	rm -f debian/changelog
	rm -rf linux firmware

