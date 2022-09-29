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

# check if the script is running with root permission
if [ "$EUID" -ne 0 ]
then
	echo "Error: Please run as root"
	exit 1
fi

MNT_DIR=/mnt
GRUB_DIR=${MNT_DIR}/EFI/fedora
GRUB_FILE=${GRUB_DIR}/grub.cfg

#variables for disk update
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PREBUILTS=${TOP_DIR}/prebuilts
FED_DISK_DIR=$PREBUILTS/refinfra
FED_DISK_NAME=fedora.satadisk

check_fedora_disk()
{
	if [ -e $FED_DISK_DIR/$FED_DISK_NAME ]
	then
		echo "Info: Found the Fedora disk image"
	else
		echo ""
		echo "Error: Fedora disk image not found. "
		echo ""
		echo "Please follow the instructions below:"
		echo ""
		echo "[1] Make sure to run this script from project's top directory"
		echo "[2] Install the Fedora distribution "
		echo "[3] Rename the installed fedora image from <random>.satadisk to fedora.satadisk"
		echo "[4] Create a folder 'refinfra' under 'prebuilts' directory "
		echo "[5] Move the installed fedora disk image to <project-loc>/prebuilts/refinfra/ folder "
		echo "[6] Run this script again from the top directory with sudo permissions"
		echo ""
		exit 1
	fi
}

update_grub ()
{
	local root_uuid=$(sed -n 93p $GRUB_FILE | awk '{print $(NF)}')
	local xfs_uuid=$(sed -n 97p $GRUB_FILE | awk '{print $(NF-2)}' | awk -F"=" '{ print $3 }')
	if ! grep -q refinfra $GRUB_FILE; then
		sed -i "84 a menuentry 'Fedora (refinfra) 27 (Server Edition)' --class fedora --class gnu-linux --class gnu --class os --unrestricted \$menuentry_id_option 'gnulinux-sgi-advanced-$xfs_uuid' --id fedora-refinfra {\n\
		load_video\n\
		insmod gzio\n\
		insmod part_gpt\n\
		insmod ext2\n\
		set root='hd0,gpt2'\n\
		if [ x\$feature_platform_search_hint = xy ]; then\n\
		search --no-floppy --fs-uuid --set=root --hint-ieee1275='ieee1275//disk@0,gpt2' --hint-bios=hd0,gpt2 --hint-efi=hd0,gpt2 --hint-baremetal=ahci0,gpt2  $root_uuid\n\
		else\n\
		search --no-floppy --fs-uuid --set=root $root_uuid\n\
		fi\n\
		linux /vmlinux-refinfra root=UUID=$xfs_uuid ro\n\
		initrd /initramfs-4.13.9-300.fc27.aarch64.img\n\
		}\
		" $GRUB_FILE

		sed -i "23 a \
		default=fedora-refinfra\
		\n" $GRUB_FILE

		echo "Info: RefInfra Linux kernel entry has been added to the Fedora Grub Menu."
		echo ""
	else
		echo "Info: RefInfra Linux kernel entry already present in Fedora Grub Menu."
		echo "Warn: Not updating the Grub menu."
		echo ""
	fi

}

package_kvm_tool ()
{
	KVM_TOOL_URL=http://http.us.debian.org/debian/pool/main/k/kvmtool/kvmtool_0.20170904-1.1_arm64.deb
	echo "Info: Downloading kvmtool binary"
	KVMDIR=$PREBUILTS/refinfra/kvmtool
	mkdir -p $KVMDIR
	pushd $KVMDIR
	wget $KVM_TOOL_URL
	echo "Info: Unpacking KVM tool binary"
	dpkg-deb -x kvmtool_0.20170904-1.1_arm64.deb .
	mv usr/bin/lkvm .
	rm -rf usr
	cp lkvm /mnt/root/
	popd
	rm -rf $KVMDIR
	echo "Info: KVM tool binary copied for Fedora disk"
	echo ""
}

unmount_disk()
{
	local loop_to_unmount=$(losetup -a | grep $FED_DISK_NAME | awk -F" " '{ print $1 }')
	loop_to_unmount=${loop_to_unmount::-1}
	echo "Info: Unmounting: $loop_to_unmount"
	umount $loop_to_unmount
}

check_fedora_disk

efi_part_offset=$(fdisk -l $FED_DISK_DIR/$FED_DISK_NAME | grep $FED_DISK_NAME\1 | awk -F" " '{ print $2 }')
sector_size=$(fdisk -l $FED_DISK_DIR/$FED_DISK_NAME | grep Units | awk '{print $(NF-1)}')
efi_part_offset=$(expr $efi_part_offset \* $sector_size)
mount -o loop,offset=$efi_part_offset $FED_DISK_DIR/$FED_DISK_NAME $MNT_DIR
update_grub
unmount_disk

root_part_offset=$(fdisk -l $FED_DISK_DIR/$FED_DISK_NAME | grep $FED_DISK_NAME\4 | awk -F" " '{ print $2 }')
root_part_offset=$(expr $root_part_offset \* $sector_size)
mount -o loop,offset=$root_part_offset $FED_DISK_DIR/$FED_DISK_NAME $MNT_DIR
package_kvm_tool
unmount_disk

echo "Info: Fedora disk preparation completed."
