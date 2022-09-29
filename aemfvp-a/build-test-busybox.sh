#!/usr/bin/env bash

# Copyright (c) 2021, ARM Limited and Contributors. All rights reserved.
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


__print_examples()
{
	echo "Example 1: ./build-scripts/$1/build-test-busybox.sh -p $1 all"
	echo "   This command builds the software stack for $1 platform and prepares a"
	echo "   disk image to boot upto busybox filesystem"
	echo
	echo "Example 2: ./build-scripts/$1/build-test-busybox.sh -p $1 clean"
	echo "   This command cleans the previous build of the $1 platform software stack"
}

__print_usage()
{
	echo
	echo "Usage: ./build-scripts/$1/build-test-busybox.sh -p <platform> <command>"
	echo
	echo "build-test-busybox.sh: Builds the disk image for busybox boot. The disk image"
	echo "consists of an EFI paritition with grub and kernel image in it and an ext3 partition as rootfs"
	echo
	echo "Supported platform is -"
	echo "aemfvp-a"
	echo
	echo "Supported build commands are - clean/build/package/all"
	echo
	__print_examples "aemfvp-a"
	echo
	exit 1
}

__parse_params_validate()
{
	#Ensure that the platform is supported
	if [ -z "$ARM_PLATFORM" ] ; then
		__print_usage "aemfvp-a"
	fi
	if [ "$ARM_PLATFORM" != "aemfvp-a" ]; then
		echo "[ERROR] Could not deduce which platform to build."
		echo "Supported platform is -"
		echo "aemfvp-a"
		exit
	fi

	#Ensure a build command is specified
	if [ -z "$BUILD_CMD" ] ; then
		__print_usage
	fi

	#Ensure that the build command is supported
	if [ "$BUILD_CMD" != "all" -a \
	     "$BUILD_CMD" != "build" -a \
	     "$BUILD_CMD" != "package" -a \
	     "$BUILD_CMD" != "clean" ] ; then
		echo "[ERROR] unsupported build command \"$BUILD_CMD\"."
		__print_usage
	fi
}

parse_params() {
	#Parse the named parameters
	while getopts "p:" opt; do
		case $opt in
			p)
				ARM_PLATFORM="$OPTARG"
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	BUILD_CMD=${@:$OPTIND:1}

	__parse_params_validate
}

#parse the command line parameters
parse_params $@

#override the command line parameters for build-all.sh
set -- "-p $ARM_PLATFORM -f busybox $BUILD_CMD"
source ./build-scripts/build-all.sh

#------------------------------------------
# Generate the disk image for busybox boot
#------------------------------------------

#variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output/$ARM_PLATFORM
OUTDIR=${PLATDIR}/components
GRUB_FS_CONFIG_FILE=${TOP_DIR}/build-scripts/$ARM_PLATFORM/grub_config/busybox.cfg
BLOCK_SIZE=512
SEC_PER_MB=$((1024*2))

create_grub_cfgfiles ()
{
	local fatpart_name="$1"

	mcopy -i  $fatpart_name -o ${GRUB_FS_CONFIG_FILE} ::/grub/grub.cfg
}

create_fatpart ()
{
	local fatpart_name="$1"  #Name of the FAT partition disk image
	local fatpart_size="$2"  #FAT partition size (in 512-byte blocks)

	dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size
	mkfs.vfat $fatpart_name

	mmd -i $fatpart_name ::/EFI
	mmd -i $fatpart_name ::/EFI/BOOT
	mmd -i $fatpart_name ::/grub

	mcopy -i $fatpart_name $TOP_DIR/$GRUB_PATH/output/grubaa64.efi ::/EFI/BOOT/bootaa64.efi
	mcopy -i $fatpart_name ${PLATDIR}/components/linux/Image ::/IMAGE

	create_grub_cfgfiles "fat_part"
	echo "FAT partition image created"
}

create_ext3part ()
{
	local ext3part_name="$1"  #Name of the ext3 partition disk image
	local ext3part_size=$2    #ext3 partition size (in 512-byte blocks)

	dd if=/dev/zero of=$ext3part_name bs=$BLOCK_SIZE count=$ext3part_size
	mkdir -p mnt
	#umount if it has been mounted
	if [[ $(findmnt -M "mnt") ]]; then
		fusermount -u mnt
	fi
	mkfs.ext3 -F $ext3part_name

	fuse-ext2 $ext3part_name mnt -o rw+
	cp -rf $TOP_DIR/$BUSYBOX_PATH/$BUSYBOX_OUT_DIR/_install/* mnt/
	sync

	pushd mnt/
	mkdir proc/ sys/ dev/ var/
	mkdir -p etc/init.d/
	cp -rf $DIR/rcS etc/init.d/

	popd

	fusermount -u mnt
	rm -rf mnt
	echo "EXT3 partition image created"
}

create_diskimage ()
{
	local image_name="$1"
	local part_start="$2"
	local fatpart_size="$3"
	local ext3part_size="$4"

	(echo n; echo 1; echo $part_start; echo +$((fatpart_size)); echo 0700; echo w; echo y) | gdisk $image_name
	(echo n; echo 2; echo $((part_start+fatpart_size)); echo +$((ext3part_size)); echo 8300; echo w; echo y) | gdisk $image_name
}

prepare_disk_image ()
{
	echo
	echo
	echo "-------------------------------------"
	echo "Preparing disk image for busybox boot"
	echo "-------------------------------------"

	pushd ${PLATDIR}/components/$PLATFORM/
	local IMG_BB=grub-busybox.img
	local FAT_SIZE_MB=100
	local EXT3_SIZE_MB=200
	local PART_START=$((1*SEC_PER_MB))
	local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB))
	local EXT3_SIZE=$((EXT3_SIZE_MB*SEC_PER_MB))

	if [ "$PLATFORM" == "aemfvp-a" ]; then
		#grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc
		#Package images for Busybox
		rm -f $IMG_BB
		dd if=/dev/zero of=part_table bs=$BLOCK_SIZE count=$PART_START

		#Space for partition table at the top
		cat part_table > $IMG_BB

		#Create fat partition
		create_fatpart "fat_part" $FAT_SIZE
		cat fat_part >> $IMG_BB

		#Create ext3 partition
		create_ext3part "ext3_part" $EXT3_SIZE
		cat ext3_part >> $IMG_BB

		#Space for backup partition table at the bottom (1M)
		cat part_table >> $IMG_BB

		# create disk image and copy into output folder
		create_diskimage $IMG_BB $PART_START $FAT_SIZE $EXT3_SIZE
		#cp $IMG_BB ${PLATDIR}/components/$PLATFORM/

		#remove intermediate files
		rm -f part_table
		rm -r ext3_part
		rm -f fat_part

	else
		#Create ext3 partition
		create_ext3part "busyboot_rootfs.img" $EXT3_SIZE
	fi

	popd
	echo "-----------------------------------------------------------"
	echo "-----------------------------------------------------------"
	echo "--  Completed preparation of disk image for busybox boot --"
	echo "-----------------------------------------------------------"
	echo "-----------------------------------------------------------"
}
if [ "$CMD" == "all" ] || [ "$CMD" == "package" ]; then
	#prepare the disk image
	prepare_disk_image
fi
