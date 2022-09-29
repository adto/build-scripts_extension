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
# SCP_BUILD_ENABLED - Flag to enable building SCP
# SCP_PATH - sub-directory containing SCP code
# SCP_PLATFORMS - List of images to build in format <PLATFORM>-<PLAT>
# SCP_BUILD_MODE - release or debug
# SCP_BYPASS_ROM_SUPPORT - Mapping of platforms that require bypass ROM support

check_cmsis_source ()
{
	# Check whether the cmsis submodule has been fetched, if not
	# fetch it
	if [[ -d "$TOP_DIR/$SCP_PATH" ]]; then
		pushd $TOP_DIR/$SCP_PATH
		echo "Fetching cmsis submodule for SCP build ... "
		git submodule update --init
		popd
	fi
}

do_build ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then

		check_cmsis_source

		pushd $TOP_DIR/$SCP_PATH
		PATH=$SCP_ARM_COMPILER_PATH:$PATH
		for item in $SCP_PLATFORMS; do
			local outdir=$TOP_DIR/$SCP_PATH/output
			mkdir -p ${outdir}

			make -j $PARALLELISM PRODUCT=$item MODE=$SCP_BUILD_MODE CC=${SCP_COMPILER_PATH}/arm-eabi-gcc
			cp -r build/product/$item/* ${outdir}/
		done
		popd
	fi
}

do_clean ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$SCP_PATH
		for item in $SCP_PLATFORMS; do
			local outdir=$TOP_DIR/$SCP_PATH/output/$item

			make PLATFORM=$item clean

			rm -rf ${outdir}
		done
		popd
	fi
}

do_package ()
{
	for plat in $SCP_PLATFORMS; do
		if [ "$SCP_BUILD_ENABLED" == "1" ]; then
			pushd $TOP_DIR
				mkdir -p ${OUTDIR}/${plat}
				cp ./${SCP_PATH}/output/scp_ramfw/${SCP_BUILD_MODE}/bin/scp_ramfw.bin ${OUTDIR}/${plat}/
				cp ./${SCP_PATH}/output/scp_romfw/${SCP_BUILD_MODE}/bin/scp_romfw.bin ${OUTDIR}/${plat}/

				if [ -d ${SCP_PATH}/output/mcp_romfw ]; then
					cp ./${SCP_PATH}/output/mcp_romfw/${SCP_BUILD_MODE}/bin/mcp_romfw.bin ${OUTDIR}/${plat}/
				fi

				if [ -d ${SCP_PATH}/output/mcp_ramfw ]; then
					cp ./${SCP_PATH}/output/mcp_ramfw/${SCP_BUILD_MODE}/bin/mcp_ramfw.bin ${OUTDIR}/${plat}/
				fi

				if [[ "${SCP_BYPASS_ROM_SUPPORT[$plat]}" = true ]]; then
					cp ./${SCP_PATH}/output/${plat}/scp/romfw_bypass.bin ${OUTDIR}/${plat}/scp-rom-bypass.bin
				fi
			popd
		else

			mkdir -p ${OUTDIR}/${plat}
			local var=SCP_PREBUILT_RAMFW_${plat}
			local fw=${!var}
			if [ -e "$fw" ]; then
				cp $fw ${OUTDIR}/${plat}/scp_ramfw.bin
			fi
			var=SCP_PREBUILT_ROMFW_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp_romfw.bin
			fi
			var=SCP_PREBUILT_ROMFW_BYPASS_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp-rom-bypass.bin
			fi

			#MCP
			local mcp_var=MCP_PREBUILT_RAMFW_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp_ramfw.bin
			fi
			mcp_var=MCP_PREBUILT_ROMFW_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp_romfw.bin
			fi
			mcp_var=MCP_PREBUILT_ROMFW_BYPASS_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp-rom-bypass.bin
			fi
		fi
	done
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
