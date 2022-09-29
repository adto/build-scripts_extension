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
# ARM_TF_PATH - for the fip tool and output images
# UBOOT_PATH - for output images
# TFTF_PATH - for TFTF output images
# TEST_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
#	arm-tf - where to find the arm-tf binaries
#	scp - the scp output directory
# 	tftf - the tftf output directory

do_build()
{
	if [ "$TEST_BINS_BUILD_ENABLED" == "1" ]; then
		echo "Build"
	fi
}

do_clean()
{
	if [ "$TEST_BINS_BUILD_ENABLED" == "1" ]; then
		echo "clean"
	fi
}

do_package()
{
	if [ "$TEST_BINS_BUILD_ENABLED" == "1" ]; then
		echo "Packaging test binaries $VARIANT";
		# Create FIPs
		local fip_tool=$TOP_DIR/$ARM_TF_PATH/tools/fip_create/fip_create
		for target in $TARGET_BINS_PLATS; do
			local tf_out=TARGET_$target[arm-tf]
			local scp_out=TARGET_$target[scp]
			local tftf_out=TARGET_$target[tftf]
			local bl2_fip_param="--bl2  ${OUTDIR}/${!tf_out}/tf-bl2.bin"
			local bl31_fip_param="--bl31 ${OUTDIR}/${!tf_out}/tf-bl31.bin"
			local bl30_fip_param=

			if [ "${!scp_out}" != "" ]; then
				bl30_fip_param="--bl30 ${OUTDIR}/scp/${!scp_out}/scp_ramfw.bin"
			fi

			if [ "${!tftf_out}" != "" ]; then
				#remove all the old fips
				rm -rf ${OUTDIR}/$target/fip-tftf.bin
				mkdir -p ${OUTDIR}/$target/
				${fip_tool} --dump  \
					${bl2_fip_param} \
					${bl31_fip_param} \
					${bl30_fip_param} \
					--bl33 ${OUTDIR}/${!tftf_out}/tftf.bin \
					${PLATTDIR}/$target/fip-tftf.bin
			fi
		done
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
