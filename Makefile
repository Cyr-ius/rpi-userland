include ../depends/Makefile.include
DEPS=../depends/Makefile.include Makefile

# lib name, version
URL_KERNEL=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-4.14.y
EMAIL=cyr-ius@ipocus.net
DEBFULLNAME=Cyr-ius Thozz
KDEB_CHANGELOG_DIST?=stretch
REV=$(shell echo "$(MODEL)" | grep -o [0-9])
EPOCH=
VERSION=$(shell make -s -C "$(CURDIR)/linux" kernelversion | grep -iv make)
SUB_VERSION=
USERLAND_VERSION=$(EPOCH)$(VERSION)$(SUB_VERSION)

export KBUILD_DEBARCH , KDEB_CHANGELOG_DIST , MODEL , DEBFULLNAME , EMAIL , MODEL, USERLAND_VERSION

LIBDYLIB=kernel

all: $(LIBDYLIB)

rbpi1 rbpi2 rbpi3 linux64:
	MODEL=$@ $(MAKE) package

.prep-files:prep-linux
	rename "s/rbpi-/$(MODEL)-/g" debian/rbpi-*
	rm -f debian/control debian/changelog
	sed "s/#MODEL#/$(MODEL)/g" debian/control.in > debian/control
	sed "s/#REV#/$(REV)/g" -i debian/control
	dch --create --distribution $(KDEB_CHANGELOG_DIST) --package "$(MODEL)-userland" "Create userland for Raspberry Pi ($(MODEL))" --newversion $(USERLAND_VERSION)
	rm -rf $(CURDIR)/firmware
	cp -r $(DEPENDS_PATH)/firmware $(CURDIR)

prep-linux:
	echo "Load linux kernel...";\
	rm -rf linux
	git clone $(URL_KERNEL) --depth=1 -b $(KERNEL_BRANCH); \


config: $(DEPS)
	$(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" $(KERNEL_DEFCONFIG)
	$(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" $(KERNEL_DEFCONFIG) kernelversion | grep [0-9]\.[0-9].* > linux/kernelversion
	$(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" $(KERNEL_DEFCONFIG) kernelrelease | grep [0-9]\.[0-9].* > linux/kernelrelease

$(LIBDYLIB): config
	- $(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" $(KERNEL_BIN_IMAGE) modules dtbs
	- $(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" bindeb-pkg

package:.prep-files
	dpkg-buildpackage -us -uc -B -a$(ARCH)
	- mv linux-* ..
	rename "s/rbpi[1|2|3]-/rbpi-/g" debian/rbpi*-*

clean:
	- $(MAKE) -C linux ARCH="$(KERNEL_ARCH)" CROSS_COMPILE="$(HOST)-" mrproper

reset:
	debclean
	rename "s/rbpi[1|2|3]-/rbpi-/g" debian/rbpi*-*
	rm -rf debian/control debian/changelog linux firmware

