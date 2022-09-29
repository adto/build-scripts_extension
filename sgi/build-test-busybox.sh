#!/usr/bin/env bash

# Copyright (c) 2018, ARM Limited and Contributors. All rights reserved.
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
platforms_rdinfra[rdn1edgex2]=1
platforms_rdinfra[rde1edge]=1
platforms_rdinfra[rddaniel]=1
platforms_rdinfra[rddanielxlr]=1

__print_examples()
{
	echo "Example 1: ./build-scripts/$refinfra/build-test-busybox.sh -p $1 all"
	echo "   This command builds the software stack for $1 platform and prepares a"
	echo "   disk image to boot upto busybox filesystem"
	echo
	echo "Example 2: ./build-scripts/$refinfra/build-test-busybox.sh -p $1 clean"
	echo "   This command cleans the previous build of the $1 platform software stack"
}

__print_usage()
{
	echo
	echo "Usage: ./build-scripts/$refinfra/build-test-busybox.sh -p <platform> <command>"
	echo
	echo "build-test-busybox.sh: Builds the disk image for busybox boot. The disk image"
	echo "consists of a EFI paritition with grub in it and a ext3 paritition with linux"
	echo "kernel image it it."
	echo
	__print_supported_platforms_$refinfra
	echo "Supported build commands are - clean/build/package/all"
	echo
	__print_examples_$refinfra
	echo
	exit 1
}

parse_params() {
	#Parse the named parameters
	while getopts "p:" opt; do
		case $opt in
			p)
				SGI_PLATFORM="$OPTARG"
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
set -- "-p $SGI_PLATFORM -f busybox $BUILD_CMD"
source ./build-scripts/build-all.sh

#------------------------------------------
# Generate the disk image for busybox boot
#------------------------------------------

#variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output/$SGI_PLATFORM
OUTDIR=${PLATDIR}/components
GRUB_FS_CONFIG_FILE=${TOP_DIR}/build-scripts/configs/$SGI_PLATFORM/grub_config/busybox.cfg
GRUB_FS_VALIDATION_CONFIG_FILE=${TOP_DIR}/build-scripts/configs/$SGI_PLATFORM/grub_config/busybox-dhcp.cfg
BLOCK_SIZE=512
SEC_PER_MB=$((1024*2))
EXT3PART_UUID=535add81-5875-4b4a-b44a-464aee5f5cbd

create_grub_cfgfiles ()
{
	local fatpart_name="$1"

	if [ "$VALIDATION_LVL" == 1 ]; then
		mcopy -i  $fatpart_name -o ${GRUB_FS_CONFIG_FILE} ::/grub/grub.cfg
	else
		mcopy -i $fatpart_name -o ${GRUB_FS_VALIDATION_CONFIG_FILE} ::/grub/grub.cfg
	fi
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
	mcopy -i $fatpart_name bootaa64.efi ::/EFI/BOOT
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
	tune2fs -U $EXT3PART_UUID $ext3part_name

	fuse-ext2 $ext3part_name mnt -o rw+
	cp $OUTDIR/linux/Image ./mnt
	cp $PLATDIR/ramdisk-busybox.img ./mnt
	sync
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

	(echo n; echo 1; echo $part_start; echo +$((fatpart_size-1)); echo 0700; echo w; echo y) | gdisk $image_name
	(echo n; echo 2; echo $((part_start+fatpart_size)); echo +$((ext3part_size-1)); echo 8300; echo w; echo y) | gdisk $image_name
	(echo x; echo c; echo 2; echo $EXT3PART_UUID; echo w; echo y) | gdisk $image_name
}

prepare_disk_image ()
{
	echo
	echo
	echo "-------------------------------------"
	echo "Preparing disk image for busybox boot"
	echo "-------------------------------------"

	pushd $TOP_DIR/$GRUB_PATH/output
	local IMG_BB=grub-busybox.img
	local FAT_SIZE_MB=20
	local EXT3_SIZE_MB=200
	local PART_START=$((1*SEC_PER_MB))
	local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB))
	local EXT3_SIZE=$((EXT3_SIZE_MB*SEC_PER_MB))

	cp grubaa64.efi bootaa64.efi
	grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc

	#Package images for Busybox
	rm -f $IMG_BB
	dd if=/dev/zero of=part_table bs=$BLOCK_SIZE count=$PART_START

	#Space for partition table at the top
	cat part_table > $IMG_BB

	#Create fat partition
	create_fatpart "fat_part" $FAT_SIZE
	create_grub_cfgfiles "fat_part"
	cat fat_part >> $IMG_BB

	#Create ext3 partition
	create_ext3part "ext3_part" $EXT3_SIZE
	cat ext3_part >> $IMG_BB

	#Space for backup partition table at the bottom (1M)
	cat part_table >> $IMG_BB

	# create disk image and copy into output folder
	create_diskimage $IMG_BB $PART_START $FAT_SIZE $EXT3_SIZE
	cp $IMG_BB $PLATDIR

	#remove intermediate files
	rm -f part_table
	rm -f fat_part
	rm -f ext3_part

	echo "Completed preparation of disk image for busybox boot"
	echo "----------------------------------------------------"
}

if [ "$CMD" == "all" ] || [ "$CMD" == "package" ]; then
	#prepare the disk image
	prepare_disk_image
fi
