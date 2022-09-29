#!/usr/bin/env bash

# Copyright (c) 2021, Arm Limited. All rights reserved.
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

# Source the main envsetup script.
if [[ ! -f "build/envsetup.sh" ]]; then
	echo "Error: Could not find build/envsetup.sh. Please call this file from root of android directory."
fi

incorrect_script_use () {
	echo "Incorrect script use, call script as:"
	echo "<path to build_android.sh> [OPTIONS]"
	echo "OPTIONS:"
	echo "-d, --distro				distro version, values supported [android-nano, android-swr]"
	echo "-a, --avb				[OPTIONAL] avb boot, values supported [true, false], DEFAULT: false"
	exit 1
}

# check if file exists and exit if it doesnt
check_file_exists_and_exit () {
	if [ ! -f $1 ]
	then
		echo "$1 does not exist"
		exit 1
	fi
}

make_ramdisk_android_image () {
	./build-scripts/common/add_uboot_header.sh
	./build-scripts/common/create_android_image.sh -a $AVB
}

AVB=false

while [[ $# -gt 0 ]]

do
	key="$1"
	case $key in
		-a|--avb)
			AVB="$2"
			shift
			shift
			;;
		-d|--distro)
			DISTRO="$2"
			shift
			shift
			;;
		*)
			incorrect_script_use
	esac
done

[ -z "$DISTRO" ] && incorrect_script_use || echo "DISTRO=$DISTRO"
[[ $AVB != true && $AVB != false ]] && incorrect_script_use || echo "AVB=$AVB"

KERNEL_IMAGE=../bsp/build-poky/tmp-poky/deploy/images/tc1/Image
. build/envsetup.sh
case $DISTRO in
    android-nano)
		if [ "$AVB" == true ]
		then
			check_file_exists_and_exit $KERNEL_IMAGE
			echo "Using $KERNEL_IMAGE for kernel"
			cp $KERNEL_IMAGE device/arm/tc
			lunch tc_nano-userdebug;
		else
			lunch tc_nano-eng;
		fi
		;;
    android-swr)
		if [ "$AVB" == true ]
		then
			check_file_exists_and_exit $KERNEL_IMAGE
			echo "Using $KERNEL_IMAGE for kernel"
			cp $KERNEL_IMAGE device/arm/tc
			lunch tc_swr-userdebug;
		else
			lunch tc_swr-eng;
		fi
		;;
    *) echo "bad option for distro $3"; incorrect_script_use
        ;;
esac
if make;
then
	make_ramdisk_android_image
else
	echo "Errors when building - will not create file system images"
fi
