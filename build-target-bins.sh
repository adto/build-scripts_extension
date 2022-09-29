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
# ARM_TF_PATH - for the fip tool / output images
# UBOOT_PATH - for mkimage / output images
# TARGET_BINS_HAS_ANDROID - whether we have android enabled
# TARGET_BINS_HAS_OE - whether we have OE enabled
# TARGET_BINS_HAS_DTB_RAMDISK - whether create dtbs with ramdisk chosen node
# LINUX_ARCH - the architecure to build the output for (arm or arm64)
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
#	arm-tf - where to find the arm-tf binaries
#	scp - the scp output directory
# 	uboot - the uboot output directory
# 	uefi - the uefi output directory
#	fdts - the fdt pattern used by the platform
#	linux - the linux image / uImage for a platform
# 	ramdisk - the address of the ramdisk per platform
# 	tbbr - flag to indicate if TBBR is enabled
# TARGET_BINS_COPY_ENABLED - whether we have extra copy steps
# TARGET_BINS_COPY_LIST - an array of "src dest" strings that
#			can be fed into a cp command. Zero based index.
# ARM_TF_ROT_KEY - Root Key location for COT generation
# TARGET_BINS_EXTRA_TAR_LIST - Extra folders that are to be tarred
# OPTEE_OS_BIN_NAME - optee os binary name
# LINUX_PATH - Path to Linux tree containing DT compiler and include files
# LINUX_OUT_DIR - output directory name
# LINUX_CONFIG_DEFAULT - the default linux build output
#
do_build()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		echo "Build"
	fi
}

do_clean()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		echo "clean"
	fi
}

append_chosen_node()
{
	# $1 = new dtb name
	# $2 = ramdisk file
	# $3 = original dtb name
	# $4 = ramdisk address
	local ramdisk_end=$(($4 + $(wc -c < $2)))
	local DTC=$TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR/$LINUX_CONFIG_DEFAULT/scripts/dtc/dtc
	# Decode the DTB
	${DTC} -Idtb -Odts -q -o$1.dts $LINUX_PATH/$3.dtb

	echo "" >> $1.dts
	echo "/ {" >> $1.dts
	echo "	chosen {" >> $1.dts
	echo "		linux,initrd-start = <$4>;" >> $1.dts
	echo "		linux,initrd-end = <${ramdisk_end}>;" >> $1.dts
	echo "	};" >> $1.dts
	echo "};" >> $1.dts

	# Recode the DTB
	${DTC} -Idts -Odtb -q -o$LINUX_PATH/$1.dtb $1.dts

	# And clean up
	rm $1.dts
}

relative_path()
{
	# both $1 and $2 are absolute paths beginning with /
	# returns relative path to $2/$target from $1/$source
	source=$2
	target=$1

	common_part=$source # for now
	result="" # for now

	while [[ "${target#$common_part}" == "${target}" ]]; do
		# no match, means that candidate common part is not correct
		# go up one level (reduce common part)
		common_part="$(dirname $common_part)"
		# and record that we went back, with correct / handling
		if [[ -z $result ]]; then
			result=".."
		else
			result="../$result"
		fi
	done

	if [[ $common_part == "/" ]]; then
		# special case for root (no common path)
		result="$result/"
	fi

	# since we now have identified the common part,
	# compute the non-common part
	forward_part="${target#$common_part}"

	# and now stick all parts together
	if [[ -n $result ]] && [[ -n $forward_part ]]; then
		result="$result$forward_part"
	elif [[ -n $forward_part ]]; then
		# extra slash removal
		result="${forward_part:1}"
	fi
	echo ${result}
}

# $1: TARGET_blah from variant
# $2: target from variant
# $3: file pattern
create_tgt_symlinks()
{
	shopt -s nullglob

	if [[ "${OUTDIR}/$1" != "${PLATDIR}/$2" ]]; then
		mkdir -p ${PLATDIR}/$2
		for bin in ${OUTDIR}/$1/$3; do
			local dirlink=$(relative_path $(dirname ${bin}) ${PLATDIR}/$1)
			local filename=$(basename ${bin})
			ln -sf  ${dirlink}/${filename} ${PLATDIR}/$2/${filename}
		done
	fi
}

# $1: ramdisk address
# $2: devtree
update_devtree()
{
	if [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
		local name=${ANDROID_BINS_VARIANTS_PLAT}
		if [ -e ${PLATDIR}/$name-ramdisk-android.img ]; then
			append_chosen_node $2-chosen-android \
				 ${PLATDIR}/$name-ramdisk-android.img $2 $1
		else
			echo "Skipping non-existing android RD for $name."
		fi
	fi
	if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
		append_chosen_node $2-chosen-oe ${PLATDIR}/ramdisk-oe.img $2 $1
	fi
	if [ "$TARGET_BINS_HAS_BUSYBOX" = "1" ] ; then
		append_chosen_node $2-chosen ${PLATDIR}/ramdisk-busybox.img $2 $1
	fi
}

do_package()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		echo "Packaging target binaries $VARIANT";
		# Add chosen node for ramdisk to dtbs
		if [ "$TARGET_BINS_HAS_DTB_RAMDISK" = "1" ]; then
			pushd ${OUTDIR}
			rm -f $LINUX_PATH/*chosen*.dtb
			for plat in $TARGET_BINS_PLATS; do
				local fd=TARGET_$plat[fdts]
				for target in ${!fd}; do
					local data=`ls $LINUX_PATH/${target}.dtb || echo ""`
					local plat_name=TARGET_$plat[output]
					for item in $data; do
						local tempy=TARGET_$plat[ramdisk]
						# remove dir and extension..
						x="$item"
						y=${x%.dtb}
						z=${y##*/}
						update_devtree ${!tempy} $z
					done
				done
			done
		fi

		if [ "$ARM_TF_PATH" != "" ]; then
			# Now do the platform stuff...
			local fip_tool=$TOP_DIR/$ARM_TF_PATH/tools/fiptool/fiptool

			echo "Using TBBR spec terminology for image name identifiers"
			local bl2_param_id="--tb-fw"
			local bl30_param_id="--scp-fw"
			local bl31_param_id="--soc-fw"
			local bl32_param_id="--tos-fw"
			local bl33_param_id="--nt-fw"
			local fw_config_param_id="--fw-config"
			local tb_fw_config_param_id="--tb-fw-config"
			local nt_fw_config_param_id="--nt-fw-config"
			local soc_fw_config_param_id="--soc-fw-config"
			local hw_config_param_id="--hw-config"
			local fw_config_fip_param=""
			local tb_fw_config_fip_param=""
			local nt_fw_config_fip_param=""
			local soc_fw_config_fip_param=""
			local hw_config_fip_param=""

			for target in $TARGET_BINS_PLATS; do
				local tf_out=TARGET_$target[arm-tf]
				local scp_out=TARGET_$target[scp]
				if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
					local uboot_out=TARGET_$target[uboot]
				fi
				if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
					local uefi_out=TARGET_$target[uefi]
				fi
				local fdt_pattern=TARGET_$target[fdts]
				local linux_bins=TARGET_$target[linux]
				local bl2_fip_param="${bl2_param_id} ${OUTDIR}/${ARM_TF_PLATS}/tf-bl2.bin"
				local bl31_fip_param="${bl31_param_id} ${OUTDIR}/${ARM_TF_PLATS}/tf-bl31.bin"
				local bl32_fip_param=
				if [ "$ARM_TF_ARCH" == "aarch32" ] || [ "$ARM_TF_AARCH32_EL3_RUNTIME" == "1" ]; then
					bl32_fip_param="${bl32_param_id} ${OUTDIR}/${ARM_TF_PLATS}/tf-bl32.bin"
				fi
				local bl30_fip_param=
				local bl30_tbbr_param=
				local cert_tool_param=
				local atf_tbbr_enabled=TARGET_$target[tbbr]
				local optee_enabled=TARGET_$target[optee]
				local optee_enabled=OPTEE_BUILD_ENABLED
				local target_name=TARGET_$target[output]

				if [ "${!scp_out}" != "" ]; then
					bl30_fip_param="${bl30_param_id} ${OUTDIR}/${!scp_out}/scp_ramfw.bin"
				fi

				#ToDo: This should be ideally be handled using additional flags for hardware
				# config fdts from the platform config files.
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_fw_config.dtb" ]; then
					fw_config_fip_param="${fw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_fw_config.dtb"
				fi
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_tb_fw_config.dtb" ]; then
					tb_fw_config_fip_param="${tb_fw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_tb_fw_config.dtb"
				fi
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_nt_fw_config.dtb" ]; then
					nt_fw_config_fip_param="${nt_fw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_nt_fw_config.dtb"
				fi
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_soc_fw_config.dtb" ]; then
					soc_fw_config_fip_param="${soc_fw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}_soc_fw_config.dtb"
				fi
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}.dtb" ]; then
					hw_config_fip_param="${hw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/${ARM_TF_PLATS}.dtb"
				fi
				if [ -f "${OUTDIR}/${ARM_TF_PLATS}/fvp-base-gicv3-psci.dtb" ]; then
					hw_config_fip_param="${hw_config_param_id} ${OUTDIR}/${ARM_TF_PLATS}/fvp-base-gicv3-psci.dtb"
				fi

				#only if a TEE implementation is available and built
				if [ "${!optee_enabled}" == "1" ]; then
					echo ${OUTDIR}/${!tf_out}/
					bl32_fip_param="${bl32_param_id} ${OUTDIR}/${!tf_out}/${OPTEE_OS_BIN_NAME}"
				fi
				#only if a MM implementation is available and built
				if [ "$UEFI_MM_BUILD_ENABLED" == "1" ]; then
					bl32_fip_param="${bl32_param_id} ${OUTDIR}/${!uefi_out}/${UEFI_MM_PAYLOAD_BIN}"
				fi

				local fip_param="${bl2_fip_param} ${bl30_fip_param} ${bl32_fip_param} ${EXTRA_FIP_PARAM} ${hw_config_fip_param} ${fw_config_fip_param} ${tb_fw_config_fip_param} ${nt_fw_config_fip_param} ${soc_fw_config_fip_param}"
				if [ "$ARM_TF_ARCH" == "aarch64" ] && [ "$ARM_TF_AARCH32_EL3_RUNTIME" != "1" ]; then
					fip_param="$fip_param ${bl31_fip_param}"
				else
					fip_param="$fip_param"
				fi
				echo "fip_param is $fip_param"

				if [ "${!atf_tbbr_enabled}" == "1" ]; then
					local trusted_key_cert_param="--trusted-key-cert ${OUTDIR}/${!tf_out}/trusted_key.crt"
					if [ "${!scp_out}" != "" ]; then
						local bl30_tbbr_param="${bl30_param_id}-key-cert ${OUTDIR}/${!tf_out}/bl30_key.crt ${bl30_param_id}-cert ${OUTDIR}/${!tf_out}/bl30.crt"
					fi
					local bl31_tbbr_param="${bl31_param_id}-key-cert ${OUTDIR}/${!tf_out}/bl31_key.crt ${bl31_param_id}-cert ${OUTDIR}/${!tf_out}/bl31.crt"
					local bl32_tbbr_param=
					local bl33_tbbr_param="${bl33_param_id}-key-cert ${OUTDIR}/${!tf_out}/bl33_key.crt ${bl33_param_id}-cert ${OUTDIR}/${!tf_out}/bl33.crt"
					local bl2_tbbr_param="${bl2_param_id}-cert ${OUTDIR}/${!tf_out}/bl2.crt"

					#only if a TEE or MM implementation is available and built
					if [ "${!optee_enabled}" == "1" ] || [ "$UEFI_MM_BUILD_ENABLED" == "1" ]; then
						bl32_tbbr_param="${bl32_param_id}-key-cert ${OUTDIR}/${!tf_out}/bl32_key.crt ${bl32_param_id}-cert ${OUTDIR}/${!tf_out}/bl32.crt"
					fi

					# add the cert related params to be used by fip_create as well as cert_create
					fip_param="${fip_param} ${trusted_key_cert_param} \
						   ${bl30_tbbr_param} ${bl31_tbbr_param} \
						   ${bl32_tbbr_param} ${bl33_tbbr_param} \
						   ${bl2_tbbr_param} ${EXTRA_TBBR_PARAM}"

					#fip_create tool and cert_create tool take almost identical params
					cert_tool_param="${fip_param} --rot-key ${ARM_TF_ROT_KEY} -n --tfw-nvctr 31 --ntfw-nvctr 223"

				fi

				if [ "${uboot_out}" ] && [ "${!uboot_out}" != "" ]; then
					# remove existing fip
					rm -f ${PLATDIR}/${!target_name}/fip-uboot.bin
					mkdir -p ${PLATDIR}/${!target_name}

					# if TBBR is enabled, generate certificates
					if [ "${!atf_tbbr_enabled}" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/cert_create/cert_create  \
							${cert_tool_param} \
							${bl33_param_id} ${OUTDIR}/${!uboot_out}/uboot.bin
					fi

					${fip_tool} create \
							${fip_param} \
							${bl33_param_id} ${OUTDIR}/${!uboot_out}/uboot.bin \
							${PLATDIR}/${!target_name}/fip-uboot.bin
					${fip_tool} info  \
							${PLATDIR}/${!target_name}/fip-uboot.bin

					local outfile=${outdir}/fip.bin
					rm -f $outfile
				fi

				if [ "$TFTF_BUILD_ENABLED" == "1" ]; then
					local tftf_out=TARGET_$target[tftf]
					# remove existing fip
					rm -f ${PLATDIR}/${!target_name}/fip-uefi.bin
					mkdir -p ${PLATDIR}/${!target_name}

					# if TBBR is enabled, generate certificates
					if [ "${!atf_tbbr_enabled}" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/cert_create/cert_create  \
							${cert_tool_param} \
							${bl33_param_id} ${OUTDIR}/${!tftf_out}/tftf.bin
					fi

					${fip_tool} update \
						${fip_param} \
						${bl33_param_id} ${OUTDIR}/${!tftf_out}/tftf.bin \
						${PLATDIR}/${!target_name}/fip-uefi.bin
					${fip_tool} info  \
						${PLATDIR}/${!target_name}/fip-uefi.bin
				fi

				if [ "${!uefi_out}" != "" ]; then
					# remove existing fip
					rm -f ${PLATDIR}/${!target_name}/fip-uefi.bin
					mkdir -p ${PLATDIR}/${!target_name}
					# if TBBR is enabled, generate certificates
					if [ "${!atf_tbbr_enabled}" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/cert_create/cert_create  \
							${cert_tool_param} \
							${bl33_param_id} ${OUTDIR}/${!uefi_out}/uefi.bin
					fi

					${fip_tool} update \
						${fip_param} \
						${bl33_param_id} ${OUTDIR}/${!uefi_out}/uefi.bin \
						${PLATDIR}/${!target_name}/fip-uefi.bin
					${fip_tool} info  \
						${PLATDIR}/${!target_name}/fip-uefi.bin
				fi

				# Create symlinks to common binaries
				if [ "${ARM_TF_PLATS}" != "" ]; then
					create_tgt_symlinks ${ARM_TF_PLATS} ${!target_name} "tf-*"
				fi
				if [ "${!scp_out}" != "" ]; then
					create_tgt_symlinks ${!scp_out} ${!target_name} "*cp_*"
				fi
				if [ "${uboot_out}" ] && [ "${!uboot_out}" != "" ]; then
					create_tgt_symlinks ${!uboot_out} ${!target_name} "uboot*"
				fi
				if [ "${!uefi_out}" != "" ]; then
					create_tgt_symlinks ${!uefi_out} ${!target_name} "uefi*"
				fi
				for tgt in ${!fdt_pattern}; do
					create_tgt_symlinks linux ${!target_name} "${tgt}*"
				done
				for item in ${!linux_bins}; do
					create_tgt_symlinks linux ${!target_name} "${item}*"
				done
			done
		fi
	fi

	if [ "$TARGET_BINS_COPY_ENABLED" == "1" ] ; then
		local array_length=${#TARGET_BINS_COPY_LIST[@]}
		for (( i=0; i<${array_length}; i++ )); do
			local copy_params=(${TARGET_BINS_COPY_LIST[$i]})
			destdir=`dirname "${copy_params[1]}"`
			test -d $destdir || mkdir -p $destdir
			cmd="cp -r ${TARGET_BINS_COPY_LIST[$i]}"
			echo $cmd
			$cmd
		done
	fi
	for tarDir in $TARGET_BINS_EXTRA_TAR_LIST ; do
		tarname=$(basename $tarDir).tar.gz
		if [ -d "$tarDir" ] ; then
			pushd $tarDir
				tar -czf ../$tarname *
			popd
		fi
	done
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
