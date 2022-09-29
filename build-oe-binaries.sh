#!/usr/bin/env bash

# Copyright (c) 2015, ARM Limited and Contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the name of ARM nor the names of its contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

#
# This script uses the following environment variables from the variant
#
# VARIANT - build variant name
# TOP_DIR - workspace root directory
# OE_BINARIES_BUILD_ENABLED - Flag to enable this script
# OE_BINARIES_PATH - sub-directory where to store Android binaries
# UBOOT_MKIMAGE - path to uboot mkimage
# LINUX_ARCH - the arch
# UBOOT_BUILD_ENABLED - flag to indicate the need for uimages.
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
# 	ramdisk - the address of the ramdisk per platform
#

do_build ()
{
	if [ "$OE_BINARIES_BUILD_ENABLED" == "1" ]; then
		:
	fi
}

do_clean ()
{
	if [ "$OE_BINARIES_BUILD_ENABLED" == "1" ]; then
		:
	fi
}

do_package ()
{
	if [ "$OE_BINARIES_BUILD_ENABLED" == "1" ]; then
		echo "Packaging OE... $VARIANT"

		mkdir -p ${PLATDIR}

		pushd ${TOP_DIR}/${OE_BINARIES_PATH}

		# Copy the binaries
		cp *.img ${PLATDIR}

		popd
	fi
	if [ "$OE_RAMDISK_BUILD_ENABLED" == "1" ]; then
		pushd ${PLATDIR}
		# OpenEmbedded ramdisks
		mkdir -p oe
		touch oe/initrd
		echo oe/initrd | cpio -ov -H newc > ramdisk-oe.img
		if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
			for target in $TARGET_BINS_PLATS; do
				local addr=TARGET_$target[ramdisk]
				${UBOOT_MKIMG} -A $LINUX_ARCH -O linux -C none \
					-T ramdisk -n ramdisk \
					-a ${!addr} -e ${!addr} \
					-n "Dummy ramdisk" \
					-d ramdisk-oe.img uInitrd-oe.${!addr}
			done
		fi
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
