#!/usr/bin/env bash

# Copyright (c) 2019, ARM Limited and Contributors. All rights reserved.
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

source ./build-scripts/sgi/sgi_common_util.sh

# List of all the supported platforms.
declare -A platforms_sgi
platforms_sgi[sgi575]=1
declare -A platforms_rdinfra
platforms_rdinfra[rdn1edge]=1
platforms_rdinfra[rde1edge]=1

TOP_DIR=`pwd`
SCT_SEQ_FILE_PATH="$TOP_DIR/build-scripts/sgi/sct.seq"

__print_examples()
{
	echo "Example 1: ./build-scripts/$refinfra/build-test-sct.sh -p $1 -s build-scripts/sgi/sct.seq all"
	echo "    This command builds the required software components of the $1"
	echo "    platform that allow a UEFI SCT image and SCT sequence file to be"
	echo "    installed to a disk."
	echo
	echo "Example 2: ./build-scripts/$refinfra/build-test-sct.sh -p $1 clean"
	echo "    This command cleans the previous build of the $1 platform software stack."
}

__print_usage()
{
	echo "Usage: ./build-scripts/$refinfra/build-test-sct.sh -p <platform> -s [sequence_file_path] <command>"
	echo
	echo "build-test-sct.sh: Builds the SGI platform software stack with all the"
	echo "required software components that allows a UEFI SCT image (and SCT"
	echo "sequence file) to be installed on a disk."
	echo
	__print_supported_platforms_$refinfra
	echo "'-s [sequence_file_path]' parameter is optional and if specified, the sequence"
	echo "file provided will be used while installing SCT on the disk or else the default"
	echo "sequence file 'sct.seq' which is present in build-scripts will be used."
	echo
	echo "Supported build commands are - clean/build/package/all"
	echo
	__print_examples_$refinfra
	echo
	exit 1
}

#callback from build-all.sh to override any build config
__do_override_build_configs()
{
	echo "$0: overriding BUILD_SCRIPTS"
	BUILD_SCRIPTS="build-arm-tf.sh build-uefi.sh build-scp.sh build-target-bins.sh build-sct.sh"
	echo "BUILD_SCRIPTS="$BUILD_SCRIPTS
}

parse_params() {
	#Parse the named parameters
	while getopts "p:s:" opt; do
		case $opt in
			p)
				SGI_PLATFORM="$OPTARG"
				;;
			s)
				SCT_SEQ_FILE_PATH=$(readlink -f "$OPTARG")
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	BUILD_CMD=${@:$OPTIND:1}

	__parse_params_validate
}

#------------------------------------------
# Generate the disk image for UEFI SCT test
#------------------------------------------

create_fatpart ()
{
	local fatpart="$1"

	dd if=/dev/zero of=$fatpart bs=$BLOCK_SIZE count=$FAT_SIZE
	mkfs.vfat $fatpart
	mmd -i $fatpart ::/EFI
	mmd -i $fatpart ::/EFI/BOOT
	mmd -i $fatpart ::/SCT

	# Install SCT
	mcopy -si $fatpart SctPackageAARCH64/AARCH64/* SctPackageAARCH64/SctStartup.nsh ::/SCT
	mcopy -i $fatpart $SCT_SEQ_FILE_PATH ::/SCT/Sequence/sct.seq -D o
	mcopy -i $fatpart $TOP_DIR/build-scripts/sgi/SctStartup.nsh ::/Startup.nsh
}

create_imagepart ()
{
	local image_name="$1"
	local image_size="$2"

	cat fat_part >> $image_name
	(echo n; echo p; echo 1; echo $PART_START; echo +$((FAT_SIZE-1)); echo t; echo 6; echo w; ) | fdisk $image_name
}

prepare_sct_disk_image ()
{
	mkdir -p $SCT_OUT_DIR
	pushd $SCT_OUT_DIR
	local IMG_SCT=uefi-sct.img
	local BLOCK_SIZE=512
	local SEC_PER_MB=$((1024*2))
	#FAT Partition size of 200MB
	local FAT_SIZE_MB=200
	local PART_START=$((1*SEC_PER_MB))
	local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB-(PART_START)))

	grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc
	#Create fat partition
	create_fatpart "fat_part"

	#Package images for SCT
	rm -f $IMG_SCT
	dd if=/dev/zero of=$IMG_SCT bs=$BLOCK_SIZE count=$PART_START
	# create image and copy into output folder
	create_imagepart $IMG_SCT $FAT_SIZE

	#remove intermediate files
	rm -f fat_part
	popd

	echo
	echo "UEFI SCT disk image file: $SCT_OUT_DIR/$IMG_SCT"
}

#parse the command line parameters
parse_params $@

#override the command line parameters for build-all.sh
set -- "-p $SGI_PLATFORM -f none $BUILD_CMD"
source ./build-scripts/build-all.sh

if [ "$CMD" = "all" ] || [ "$CMD" = "package" ]; then
	#prepare the SCT test disk image
	prepare_sct_disk_image
fi

if [ "$CMD" = "clean" ]; then
	rm -f $SCT_OUT_DIR/uefi-sct.img
fi
