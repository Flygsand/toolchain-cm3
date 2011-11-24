#
# Makefile to download, build and install an arm-elf toolchain
# For documentation see below
#
# Copyright (C) 2008-2010 Thomas Giesel
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
# Thomas Giesel skoe@directbox.com
#
# Lazy CMSIS integration added by Ingo Korb <ingo@akana.de>
#

# Tested in Ubuntu/Xubuntu/Kubuntu 7.10, 8.04, Cygwin, Gentoo
# 
# Following conditions must be met to sucessfully build the toolchain:
# - Be sure to have these packages installed
#     libmpfr-dev >= 2.3.0
#     libgmp3-dev >= 4.2
#     make        >= 3.81 (GNU Make)
#     gawk
#

# that's the place where the toolchain is going to be installed
#prefix           = $(HOME)/cross/$(target)-$(binutils)-$(gcc)
prefix = /opt/$(target)-$(patsubst gcc-%,%,$(gcc))
# (use no ':=' above)

# in case you need sudo for installing
sudo      :=
#sudo      := sudo

wget_opts	:= -t 60 -T 100

here            := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
build           := $(here)/build
archive         := $(here)/archive
cleandirs       :=

binutils        := binutils-2.20.1
binutils_path   := http://ftp.gnu.org/gnu/binutils

gccfile         := gcc-4.4.6
gcc             := gcc-4.4.6
gcc_path        := ftp://ftp.fu-berlin.de/unix/languages/gcc/releases
#gcc_tmp_prefix  := $(build)/gcc-tmp-install

gdb             := gdb-7.1
gdb_path        := http://ftp.gnu.org/gnu/gdb

insight         := insight-6.8-1
insight_path    := ftp://sourceware.org/pub/insight/releases

newlib          := newlib-1.19.0
newlib_path     := ftp://sources.redhat.com/pub/newlib

cmsis           := CMSIS_V1P30
cmsis_archive   := cmsis_v1p30.zip
cmsis_path      := http://www.onarm.com/download/files

#target          := armv7m-none-eabi
target          := arm-none-eabi

# this variable will be empty if we're not on cygwin
cygwin    := $(shell echo $$MACHTYPE | grep cygwin)

ifeq (x$(cygwin), x)
  path      := $(prefix)/bin:$(PATH)
else
  # don't use all these windows paths
  path      := $(prefix)/bin:/bin:/usr/bin
endif

# automatic number-of-cpus detection for Linux
ifeq ($(shell uname), Linux)
  parallel := -j$(shell grep ^processor /proc/cpuinfo|wc -l)
endif

###############################################################################
### Main rules
###############################################################################

.PHONY: all
all: gcc gdb insight cmsis headers


###############################################################################
### BINUTILS
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: binutils
binutils: $(prefix)/bin/$(target)-objdump

$(prefix)/bin/$(target)-objdump: $(build)/$(binutils)
	mkdir -p $(build)/obj-$(binutils)
	cd $(build)/obj-$(binutils) && $(build)/$(binutils)/configure \
		--target=$(target) \
		--prefix=$(prefix) --disable-nls \
		--enable-interwork --disable-multilib \
		--with-gnu-as --with-gnu-ld
	cd $(build)/obj-$(binutils) && make $(parallel)
	cd $(build)/obj-$(binutils) && $(sudo) make install

$(build)/$(binutils): $(archive)/$(binutils).tar.bz2
	mkdir -p $(build)
	cd $(build) && tar xjf $(archive)/$(binutils).tar.bz2

$(archive)/$(binutils).tar.bz2:
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(binutils_path)/$(binutils).tar.bz2
	touch $@

###############################################################################
### GCC tmp
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: gcctmp
gcctmp: $(prefix)/bin/$(target)-gccbla

$(prefix)/bin/$(target)-gccbla: $(build)/$(gcc) | binutils
	mkdir -p $(build)/obj-$(gcc)-tmp
	cd $(build)/obj-$(gcc)-tmp && PATH=$(path) \
		$(build)/$(gcc)/configure \
		--target=$(target) \
		--prefix=$(prefix) --disable-nls \
		--with-cpu=cortex-m3 --with-mode=thumb \
		--enable-interwork --disable-multilib --enable-languages="c" \
		--with-newlib --without-headers --disable-shared \
		--with-gnu-as --with-gnu-ld
	cd $(build)/obj-$(gcc)-tmp && PATH=$(path) make $(parallel) all-gcc
	cd $(build)/obj-$(gcc)-tmp && PATH=$(path) make install-gcc

$(build)/$(gcc): $(archive)/$(gccfile).tar.bz2
	mkdir -p $(build)
	cd $(build) && tar xjf $(archive)/$(gccfile).tar.bz2
	touch $@

$(archive)/$(gccfile).tar.bz2:
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(gcc_path)/$(gcc)/$(gccfile).tar.bz2

###############################################################################
### Newlib
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: newlib
newlib: $(prefix)/bin/$(target)-blabla

$(prefix)/bin/$(target)-blabla: $(build)/$(newlib) | gcctmp
	mkdir -p $(build)/obj-$(newlib)
	cd $(build)/obj-$(newlib) && \
		PATH=$(path) \
		$(build)/$(newlib)/configure \
		--target=$(target) \
		--prefix=$(prefix) --disable-nls \
		--enable-interwork --disable-multilib \
		--with-gnu-as --with-gnu-ld \
		--disable-newlib-supplied-syscalls
	cd $(build)/obj-$(newlib) && PATH=$(path) make $(parallel)
	cd $(build)/obj-$(newlib) && $(sudo) PATH=$(path) make install

$(build)/$(newlib): $(archive)/$(newlib).tar.gz
	mkdir -p $(build)
	cd $(build) && tar xzf $(archive)/$(newlib).tar.gz
	touch $@

$(archive)/$(newlib).tar.gz:
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(newlib_path)/$(newlib).tar.gz

###############################################################################
### GCC final
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: gcc
gcc: $(prefix)/bin/$(target)-gccfinal

$(prefix)/bin/$(target)-gccfinal: $(build)/$(gcc) | newlib
	mkdir -p $(build)/obj-$(gcc)
	cd $(build)/obj-$(gcc) && PATH=$(path) \
		$(build)/$(gcc)/configure \
		--target=$(target) \
		--prefix=$(prefix) --disable-nls \
		--with-cpu=cortex-m3 --with-mode=thumb \
		--enable-interwork --disable-multilib --enable-languages="c,c++" \
		--with-newlib --disable-shared \
		--with-gnu-as --with-gnu-ld
	cd $(build)/obj-$(gcc) && PATH=$(path) make $(parallel)
	cd $(build)/obj-$(gcc) && PATH=$(path) make install

###############################################################################
### GDB
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: gdb
gdb: $(prefix)/bin/$(target)-gdb

$(prefix)/bin/$(target)-gdb: $(build)/$(gdb)
	mkdir -p $(build)/obj-$(gdb)
	cd $(build)/obj-$(gdb) && $(build)/$(gdb)/configure \
		--target=$(target) --prefix=$(prefix) --disable-nls \
		--disable-werror
	cd $(build)/obj-$(gdb) && make $(parallel)
	cd $(build)/obj-$(gdb) && $(sudo) make install

$(build)/$(gdb): $(archive)/$(gdb).tar.bz2
	mkdir -p $(build)
	cd $(build) && tar xjf $(archive)/$(gdb).tar.bz2
	touch $@

$(archive)/$(gdb).tar.bz2:
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(gdb_path)/$(gdb).tar.bz2

###############################################################################
### Insight
###############################################################################

# we use an example executable to find out if it is installed already
.PHONY: insight
insight: $(prefix)/bin/$(target)-insight

$(prefix)/bin/$(target)-insight: $(build)/$(insight)
	mkdir -p $(build)/obj-$(insight)
	cd $(build)/obj-$(insight) && $(build)/$(insight)/configure \
		--target=$(target) --prefix=$(prefix) --disable-nls \
		--disable-werror
	cd $(build)/obj-$(insight) && make $(parallel)
	cd $(build)/obj-$(insight) && $(sudo) make install

$(build)/$(insight): $(archive)/$(insight).tar.bz2
	mkdir -p $(build)
	cd $(build) && tar xjf $(archive)/$(insight).tar.bz2
	touch $@

$(archive)/$(insight).tar.bz2:
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(insight_path)/$(insight).tar.bz2

###############################################################################
### CMSIS
###############################################################################

# official functions for the M3 core
.PHONY: cmsis
cmsis: $(prefix)/$(target)/lib/libcore_cm3.a

# Lazy version, CM3 only, doesn't do any crt/linkscript stuff
$(prefix)/$(target)/include/arm/core_cm3.h: $(build)/$(cmsis)/.patched
	mkdir -p $(prefix)/$(target)/include/arm
	cp $(build)/$(cmsis)/CM3/CoreSupport/core_cm3.h $(prefix)/$(target)/include/arm
	cd $(build)/$(cmsis)/CM3/DeviceSupport && tar cf - . | (cd $(prefix)/$(target)/include/arm && tar xf -)

# Compile library after header file is installed
$(build)/$(cmsis)/core_cm3.o: $(prefix)/$(target)/include/arm/core_cm3.h
	$(target)-gcc -O -o $@ -c $(build)/$(cmsis)/CM3/CoreSupport/core_cm3.c

# Archive into lib
$(prefix)/$(target)/lib/libcore_cm3.a: $(build)/$(cmsis)/core_cm3.o
	$(target)-ar rcs $@ $<

# reduce and patch CMSIS - just header files, no startup/system code
$(build)/$(cmsis)/.patched: $(build)/$(cmsis)
	find $(build)/$(cmsis)/CM3/DeviceSupport -name startup|xargs rm -rf
	find $(build)/$(cmsis)/CM3/DeviceSupport -name system_\*|xargs rm -f
	find $(build)/$(cmsis)/CM3/CoreSupport $(build)/$(cmsis)/CM3/DeviceSupport -name \*.h -o -name \*.c|xargs recode -f /CRLF..
	cd $(build)/$(cmsis) && patch -p1 < $(here)/patches/$(cmsis)_cleanup.diff
	touch $@

$(build)/$(cmsis): $(archive)/$(cmsis_archive)
	mkdir -p $(build)
	cd $(build) && unzip $(archive)/$(cmsis_archive)
	touch $@

$(archive)/$(cmsis_archive):
	mkdir -p $(archive)
	cd $(archive) && wget $(wget_opts) $(cmsis_path)/$(cmsis_archive)

###############################################################################
### Headers
###############################################################################

# unofficial header files with stuff I like
.PHONY: headers
headers: $(prefix)/$(target)/include/arm/bits.h

# FIXME: Needs to be extended per-header - use $(wildcard ...) ?
$(prefix)/$(target)/include/arm/bits.h: $(here)/headers/bits.h
	mkdir -p $(prefix)/$(target)/include/arm
	cp $(here)/headers/bits.h $(prefix)/$(target)/include/arm

###############################################################################
### Clean
###############################################################################

# clean removes everything which could be different on a new build
clean:
	rm -rf $(build)
