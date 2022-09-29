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
# ARM_TF_ARCH - aarch64 or aarch32
# ARM_TF_BUILD_ENABLED - Flag to enable building ARM Trusted Firmware
# ARM_TF_PATH - sub-directory containing ARM Trusted Firmware code
# ARM_TF_PLATS - List of platforms to be built (from available in arm-tf/plat)
# ARM_TF_DEBUG_ENABLED - 1 = debug, 0 = release build
# ARM_TF_BUILD_FLAGS - Additional build flags to pass on the build command line
# ARM_TF_TBBR_BUILD_FLAGS - command line options to enable TBBR in ARM TF build
# OPTEE_BUILD_ENABLED - Flag to indicate if optee is enabled
# TBBR_{plat} - array of platform parameters, indexed by
# 	tbbr - flag to indicate if TBBR is enabled
#

do_build ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$ARM_TF_PATH
		for plat in $ARM_TF_PLATS; do
			local atf_build_flags=$ARM_TF_BUILD_FLAGS
			local atf_tbbr_enabled=TARGET_$plat[tbbr]
			local atf_optee_enabled=OPTEE_BUILD_ENABLED
			if [ "${!atf_tbbr_enabled}" == "1" ]; then
				#if trusted board boot(TBBR) enabled, set corresponding compiliation flags
				atf_build_flags="${atf_build_flags} $ARM_TF_TBBR_BUILD_FLAGS"
			fi
			if [ "${!atf_optee_enabled}" == "1" ]; then
				#if optee enabled, set corresponding compiliation flags
				atf_build_flags="${atf_build_flags} ARM_TSP_RAM_LOCATION=$OPTEE_RAM_LOCATION"
				atf_build_flags="${atf_build_flags} SPD=opteed"
			fi
			if [ "$ARM_TF_AARCH32_EL3_RUNTIME" == "1" ]; then
				CROSS_COMPILE=$CROSS_COMPILE_32 \
				make -j $PARALLELISM PLAT=$plat ARCH=aarch32 DEBUG=$ARM_TF_DEBUG_ENABLED $ARM_TF_BL32_FLAGS bl32
				rm -rf build/juno/release/lib*
				targets="bl1 bl2 bl31"
			else
				targets="all"
			fi
			# HACK: this is to deal with juno32 building ARM-TF BL1 and BL2 as Aarch64
			#       but everything else as Aarch32
			if [ "$ARM_TF_ARCH" == "aarch32" ]; then
				TMP_CROSS_COMPILE=$CROSS_COMPILE_32
			else
				TMP_CROSS_COMPILE=$CROSS_COMPILE_64
			fi
		
			echo "CROSS_COMPILE=$TMP_CROSS_COMPILE"
			echo "make -j $PARALLELISM PLAT=$plat ARCH=$ARM_TF_ARCH ENABLE_RME=1 DEBUG=$ARM_TF_DEBUG_ENABLED ${atf_build_flags} ${targets}"
			CROSS_COMPILE=$TMP_CROSS_COMPILE \
			make -j $PARALLELISM PLAT=$plat ARCH=$ARM_TF_ARCH ENABLE_RME=1 DEBUG=$ARM_TF_DEBUG_ENABLED ${atf_build_flags} ${targets}
		done

		# make tools
		make -j $PARALLELISM certtool
		make -j $PARALLELISM fiptool
		popd
	fi
}

do_clean ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$ARM_TF_PATH

		for plat in $ARM_TF_PLATS; do
			make PLAT=$plat DEBUG=$ARM_TF_DEBUG_ENABLED clean
		done
		if [ -e tools/fip_create/Makefile ]; then
			make -C tools/fip_create clean
		fi
		if [ -e tools/fiptool/Makefile ]; then
			make -C tools/fiptool clean
		fi
		popd
	fi
}

do_package ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		echo "Packaging arm-tf... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR
		for plat in $ARM_TF_PLATS; do
			mkdir -p ${OUTDIR}/$plat
			local mode=release
			[ "$ARM_TF_DEBUG_ENABLED" == "1" ] && mode=debug
			for bin in $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/bl*.bin; do
				cp ${bin} ${OUTDIR}/$plat/tf-$(basename ${bin})
			done
            
            #adto fix
            if [ -e $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/rmm.bin ]; then
				cp $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/rmm.bin ${OUTDIR}/$plat/
			fi
            #end of adto fix
            
			if [ -e $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/fdts ]; then
				cp $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/fdts/*.dtb ${OUTDIR}/$plat/
			fi
		done
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
