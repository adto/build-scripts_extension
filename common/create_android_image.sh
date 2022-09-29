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

set -e

if [ -z "$ANDROID_PRODUCT_OUT" ]
then
      echo "var ANDROID_PRODUCT_OUT is empty"
      exit 1
fi

incorrect_script_use () {
	echo "Incorrect script use, call script as:"
	echo "<path to create_android_image.sh> [OPTIONS]"
	echo "OPTIONS:"
	echo "-a, --avb				[OPTIONAL] avb boot, values supported [true, false], DEFAULT: false"
	echo "If using an android distro, export ANDROID_PRODUCT_OUT variable to point to android out directory"
	exit 1
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
		*)
			incorrect_script_use
	esac
done

if [ "$AVB" == true ]
then
	echo "Creating android image with system, data, boot and vbmeta partitions"
else
	echo "Creating android image with system and data partitions"
fi

pushd .

cd $ANDROID_PRODUCT_OUT

IMG=${IMG:-android.img}

size_in_mb() {
	local size_in_bytes
	size_in_bytes=$(wc -c $1)
	size_in_bytes=${size_in_bytes%% *}
	echo $((size_in_bytes / 1024 / 1024 + 1))
}

SYSTEM_IMG=${SYSTEM_IMG:-system.img}
SYSTEM_SIZE=$(size_in_mb ${SYSTEM_IMG})
USERDATA_IMG=${USERDATA_IMG:-userdata.img}
USERDATA_SIZE=$(size_in_mb ${USERDATA_IMG})

if [ "$AVB" == true ]
then
	VBMETA_IMG=${VBMETA_IMG:-vbmeta.img}
	VBMETA_SIZE=$(size_in_mb ${VBMETA_IMG})
	BOOT_IMG=${BOOT_IMG:-boot.img}
	BOOT_SIZE=$(size_in_mb ${BOOT_IMG})

	IMAGE_LEN=$((BOOT_SIZE + VBMETA_SIZE + SYSTEM_SIZE + USERDATA_SIZE + 2 ))
else
	IMAGE_LEN=$((SYSTEM_SIZE + USERDATA_SIZE + 2 ))
fi

# measured in MBytes
PART1_START=1
PART1_END=$((PART1_START + SYSTEM_SIZE))
PART2_START=${PART1_END}
PART2_END=$((PART2_START + USERDATA_SIZE))
if [ "$AVB" == true ]
then
	PART3_START=${PART2_END}
	PART3_END=$((PART3_START + VBMETA_SIZE))
	PART4_START=${PART3_END}
	PART4_END=$((PART4_START + BOOT_SIZE))
fi

PARTED="parted -a min "

# Create an empty disk image file
dd if=/dev/zero of=$IMG bs=1M count=$IMAGE_LEN

# Create a partition table
$PARTED $IMG unit s mktable gpt

# Create partitions
SEC_PER_MB=$((1024*2))
$PARTED $IMG unit s mkpart system ext4 $((PART1_START * SEC_PER_MB)) $((PART1_END * SEC_PER_MB - 1))
$PARTED $IMG unit s mkpart data ext4 $((PART2_START * SEC_PER_MB)) $((PART2_END * SEC_PER_MB - 1))
if [ "$AVB" == true ]
then
	$PARTED $IMG unit s mkpart vbmeta ext4 $((PART3_START * SEC_PER_MB)) $((PART3_END * SEC_PER_MB - 1))
	$PARTED $IMG unit s mkpart boot ext4 $((PART4_START * SEC_PER_MB)) $((PART4_END * SEC_PER_MB - 1))
fi

# Assemble all the images into one final image
dd if=$SYSTEM_IMG of=$IMG bs=1M seek=${PART1_START} conv=notrunc
dd if=$USERDATA_IMG of=$IMG bs=1M seek=${PART2_START} conv=notrunc
if [ "$AVB" == true ]
then
	dd if=$VBMETA_IMG of=$IMG bs=1M seek=${PART3_START} conv=notrunc
	dd if=$BOOT_IMG of=$IMG bs=1M seek=${PART4_START} conv=notrunc
fi

popd