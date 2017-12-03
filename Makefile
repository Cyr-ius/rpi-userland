# lib name, version
URL_KERNEL=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-4.14.y
URL_FIRMWARE=https://github.com/raspberrypi/firmware
FIRMWARE_BRANCH=next

NUMCPUS=$(shell grep -c '^processor' /proc/cpuinfo)
CROSS_COMPILE?=$(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)
RPI_MODEL?=2

ifeq ($(RPI_MODEL),1)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcmrpi_defconfig
endif

ifeq ($(RPI_MODEL),2)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcm2709_defconfig
endif

ifeq ($(RPI_MODEL),3)
	ARCH=arm64
	KERNEL_BIN_IMAGE=Image
	KERNEL_DEFCONFIG=bcmrpi3_defconfig         
endif

ifeq ($(CROSS_COMPILE),arm-linux-gnueabihf)
	KBUILD_DEBARCH=armhf
endif

ifeq ($(CROSS_COMPILE),arm-linux-gnueabi)
	KBUILD_DEBARCH=armel
endif

ifeq ($(CROSS_COMPILE),aarch64-linux-gnu)
	KBUILD_DEBARCH=arm64
endif

export EMAIL="cyr-ius@ipocus.net"
export DEBFULLNAME="Cyr-ius Thozz"
export KBUILD_DEBARCH

all: .installed

.installed: firmware
	
firmware: prep-package
	@if  [ ! -d firmware ];then \
		echo "Load firmware...";\
		git clone $(URL_FIRMWARE) --depth=1 -b $(FIRMWARE_BRANCH); \
	fi	

linux:
	if  [ ! -d linux ];then \
		echo "Load linux kernel...";\
		git clone $(URL_KERNEL) --depth=1 -b $(KERNEL_BRANCH); \
	fi	
	make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" mrproper
	make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_DEFCONFIG)
	make -j$(NUMCPUS) deb-pkg -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_BIN_IMAGE) modules dtbs

prep-package: linux
	RELEASE=$(shell cat "linux/include/config/kernel.release")
	REVISION=$(shell cat linux/.version)
	VERSION=$(RELEASE)-$(RELEASE)


clean:
	rm -rf linux firmware

distclean::
	rm -rf linux firmware
