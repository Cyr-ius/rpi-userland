# lib name, version
URL_KERNEL=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-4.14.y
URL_FIRMWARE=https://github.com/raspberrypi/firmware
FIRMWARE_BRANCH=next
EMAIL="cyr-ius@ipocus.net"
DEBFULLNAME="Cyr-ius Thozz"

NUMCPUS=$(shell grep -c '^processor' /proc/cpuinfo)
CROSS_COMPILE?=$(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)
RPI_MODEL?=2

ifeq ($(RPI_MODEL),1)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcmrpi_defconfig
	KBUILD_DEBARCH=armhf
endif

ifeq ($(RPI_MODEL),2)
	ARCH=arm
	KERNEL_BIN_IMAGE=zImage
	KERNEL_DEFCONFIG=bcm2709_defconfig
	KBUILD_DEBARCH=armhf	
endif

ifeq ($(RPI_MODEL),3)
	ARCH=arm64
	KERNEL_BIN_IMAGE=Image
	KERNEL_DEFCONFIG=bcmrpi3_defconfig
	KBUILD_DEBARCH=arm64	
endif

export KBUILD_DEBARCH , RPI_MODEL , DEBFULLNAME , EMAIL

all:prep-package

.prep-files:
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/changelog
	rename s/rpi-/rpi$(RPI_MODEL)-/ debian/rpi-*
	sed s/rpi-/rpi$(RPI_MODEL)-/ -i debian/control
	sed s/rpi-/rpi$(RPI_MODEL)-/ -i debian/changelog

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

.make-linux:.prep-linux
	- make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" mrproper
	- make -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_DEFCONFIG)
	- make -j$(NUMCPUS) deb-pkg -C "linux" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)-" $(KERNEL_BIN_IMAGE) modules dtbs

prep-package:.make-linux
	$(eval RELEASE=$(shell cat "linux/include/config/kernel.release"))
	$(eval REVISION=$(shell cat linux/.version))
	$(eval VERSION=$(RELEASE)-$(REVISION))
	dch -v $(VERSION) -D stretch "Linux Kernel Package $(VERSION)"

package:.prep-files
	dpkg-buildpackage -us -uc -B -aarmhf
	mv linux-* ..
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/changelog

reset:
	debclean
	rename "s/rpi[1|2|3]-/rpi-/" debian/rpi*-*
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/control
	sed "s/rpi[1|2|3]-/rpi-/" -i debian/changelog
	rm -rf linux firmware

