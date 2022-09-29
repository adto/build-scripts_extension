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
# ANDROID_BUILD_ENABLED - Flag to enable building Android
# ANDROID_SOURCE_PATH - sub-directory containing Android
# ANDROID_BINARIES_PATH - sub-directory containing Android prebuilt bins
# ANDROID_LUNCH_TARGET - Lunch target to build
# ANDROID_IMAGE_SIZE - Size of the image to generate
# UBOOT_MKIMAGE - path to uboot mkimage
# LINUX_ARCH - the arch
# UBOOT_BUILD_ENABLED - flag to indicate the need for uimages.
# ANDROID_BINS_VARIANTS - list of binary distros
# TARGET_{plat} - array of platform parameters, indexed by
# 	ramdisk - the address of the ramdisk per platform
# OPTEE_OS_PATH - path to optee os
# OPTEE_PLATFORM - optee build target
#

do_build ()
{
	if [ "$ANDROID_BUILD_ENABLED" == "1" ]; then
		if [ -d "$TOP_DIR/$ANDROID_SOURCE_PATH" ]; then
			pushd $TOP_DIR/$ANDROID_SOURCE_PATH

			echo "Android source build starting."
			# android build system allows to specify external (to android) optee_os build path.
			# This is done to ensure that TAs built from android build system are linked/compiled
			#  against right secure world libraries and headers.
			# Also, the path has to be relative to android top dir.
			export TA_DEV_KIT_DIR=../$OPTEE_OS_PATH/out/arm-plat-$OPTEE_PLATFORM/export-ta_arm64
			echo "export TA_DEV_KIT_DIR=../$OPTEE_OS_PATH/out/arm-plat-$OPTEE_PLATFORM/export-ta_arm64"
			source build/envsetup.sh
			lunch ${ANDROID_LUNCH_TARGET}
			make -j $PARALLELISM USE_NINJA=false TARGET_NO_KERNEL=true \
				BUILD_KERNEL_MODULES=false \
				systemimage userdataimage ramdisk

			popd
		else
			echo "Android binary build. Skipping."
		fi
	fi
}

do_clean ()
{
	if [ "$ANDROID_BUILD_ENABLED" == "1" ]; then
		if [ -d "$TOP_DIR/$ANDROID_SOURCE_PATH" ]; then
			pushd $TOP_DIR/$ANDROID_SOURCE_PATH
			echo "Cleaning Android source build..."
			rm -rf out
			popd
		else
			echo "Android binary build. Skipping."
		fi
	fi
}

do_package ()
{
	if [ "$ANDROID_BUILD_ENABLED" == "1" ]; then
		echo "Packaging Android... $VARIANT";

		mkdir -p ${PLATDIR}

		if [ -d "$TOP_DIR/$ANDROID_SOURCE_PATH" ]; then
			pushd $TOP_DIR/$ANDROID_SOURCE_PATH
			echo "Packaging Android source build..."

			# Setup lunch option to have access to env variables
			source build/envsetup.sh
			lunch ${ANDROID_LUNCH_TARGET}

			# ANDROID_PRODUCT_OUT env variable is exported by android build system,
			# when  'lunch <target>' is run.
			local product_out=${ANDROID_PRODUCT_OUT}
			local make_ext4fs=${TOP_DIR}/${ANDROID_SOURCE_PATH}/out/host/linux-x86/bin/make_ext4fs

			pushd ${product_out}
			# Create an image file
			MAKE_EXT4FS=${make_ext4fs} \
				IMG=${PLATDIR}/${ANDROID_BINS_VARIANTS}-android.img \
				$TOP_DIR/build-scripts/android-image.sh

			# Copy the ramdisk
			cp ${product_out}/ramdisk.img \
				${PLATDIR}/${ANDROID_BINS_VARIANTS}-ramdisk-android.img
			popd
		else
			pushd ${TOP_DIR}/${ANDROID_BINARIES_PATH}/${PLATFORM}
			echo "Packaging Android binary build..."
			# Create an image file
			if [ -e "system.img" ]; then
				IMG=${PLATDIR}/${ANDROID_BINS_VARIANTS}-android.img \
					${TOP_DIR}/build-scripts/android-image.sh
			elif [ -e "${ANDROID_BINS_VARIANTS}.img" ]; then
				# platform image already created
				cp ${ANDROID_BINS_VARIANTS}.img ${PLATDIR}/${ANDROID_BINS_VARIANTS}-android.img
			else
				echo "Error: no system image available for ${ANDROID_BINS_VARIANTS}"
			fi
			# Copy the ramdisk
			cp ramdisk.img ${PLATDIR}/${ANDROID_BINS_VARIANTS}-ramdisk-android.img
			popd
		fi
		if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
			# Android ramdisks for uboot
			pushd ${PLATDIR}
				local addr=TARGET_$ANDROID_BINS_VARIANTS[ramdisk]
				${UBOOT_MKIMG} -A $LINUX_ARCH -O linux -C none \
					-T ramdisk -n ramdisk \
					-a ${!addr} -e ${!addr} \
					-n "Android ramdisk" \
					-d ${ANDROID_BINS_VARIANTS}-ramdisk-android.img \
					${ANDROID_BINS_VARIANTS}-uInitrd-android.${!addr}
			popd
		fi
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
