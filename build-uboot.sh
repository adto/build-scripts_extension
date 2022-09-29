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
# CROSS_COMPILE - PATH to GCC including CROSS-COMPILE prefix
# UBOOT_BUILD_ENABLED - Flag to enable building u-boot
# UBOOT_PATH - sub-directory containing u-boot code
# UBOOT_ARCH - Build architecture (aarch64)
# UBOOT_BOARDS - List of board images to build
#
# To create uImage in package step Linux must be before uboot in the variant
# file

do_build ()
{
	if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
		export ARCH=$UBOOT_ARCH

		pushd $TOP_DIR/$UBOOT_PATH
		for item in $UBOOT_BOARDS; do
			local outdir=output/$item
			make -j $PARALLELISM O=$outdir ${item}_config
			scripts/kconfig/merge_config.sh -O $outdir  $outdir/.config $UBOOT_CONFIG
			make -j $PARALLELISM O=$outdir
			cp -R $outdir/tools output
		done
		popd
	fi
}

do_clean ()
{
	if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
		export ARCH=$UBOOT_ARCH

		pushd $TOP_DIR/$UBOOT_PATH
		make distclean
		rm -rf output
		popd
	fi
}

do_package ()
{
	if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
		echo "Packaging uboot... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR
		for item in $UBOOT_BOARDS; do
			mkdir -p ${OUTDIR}/${UBOOT_OUTPUT_DESTS[$item]}
			cp ./$UBOOT_PATH/output/$item/u-boot.bin ${OUTDIR}/${UBOOT_OUTPUT_DESTS[$item]}/uboot.bin
		done
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
