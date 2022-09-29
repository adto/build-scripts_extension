#!/usr/bin/env bash

# Copyright (c) 2016, ARM Limited and Contributors. All rights reserved.
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
# OUTDIR - output dir for final packaging
# TOP_DIR - workspace root directory
# CROSS_COMPILE - aarch64 cross compiler
# CROSS_COMPILE_32 - aarch32 cross compiler
# OPTEE_BUILD_ENABLED - Flag to enable building optee
# OPTEE_OS_PATH - path to optee os code
# OPTEE_OS_BIN_NAME - name of the optee os executable bin
# OPTEE_CORE_LOG_LEVEL - 1-> least debug logs, 4-> most debug logs
# OPTEE_PLATFORM - optee platform
# OPTEE_FLAVOR - optee platform flavor
# OPTEE_OS_AARCH64_CORE - Flag to decide aarch32 or aarch64 build
#

do_build ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		echo "Building OPTEE for platform $OPTEE_PLATFORM and flavour $OPTEE_FLAVOUR"
		local optee_plat=OPTEE_PLATFORM
		local optee_plat_flavor=OPTEE_FLAVOUR
		export CROSS_COMPILE64=$CROSS_COMPILE
		export CROSS_COMPILE32=$CROSS_COMPILE_32
		export PLATFORM=${!optee_plat}
		export PLATFORM_FLAVOR=${!optee_plat_flavor}
		export CFG_TEE_CORE_LOG_LEVEL=$OPTEE_CORE_LOG_LEVEL
		export CFG_ARM64_core=$OPTEE_OS_AARCH64_CORE
		pushd $TOP_DIR/$OPTEE_OS_PATH
		make -j$PARALLELISM
		## temp patch: to be fixed by proper memory mapping of TEE
		mkdir -p out/arm-plat-${PLATFORM_FLAVOR}/core
		${CROSS_COMPILE}objcopy -O binary out/arm-plat-${PLATFORM}/core/tee.elf out/arm-plat-${PLATFORM_FLAVOR}/core/${OPTEE_OS_BIN_NAME}
		popd
		# optee client build
		# temp patch: this will be removed once we have the client built in the LCR/OE
		echo "Build optee client.."
		pushd $TOP_DIR/optee/optee_client
		make -j$PARALLELISM CROSS_COMPILE=${CROSS_COMPILE}
		popd
	fi
}

do_clean ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		SAVE_PLATFORM=$PLATFORM
		unset PLATFORM
		local optee_plat=OPTEE_PLATFORM
		local optee_plat_flavor=OPTEE_FLAVOUR
		export PLATFORM=${!optee_plat}
		export PLATFORM_FLAVOR=${!optee_plat_flavor}
		export CFG_ARM64_core=$OPTEE_OS_AARCH64_CORE
		pushd $TOP_DIR/$OPTEE_OS_PATH
		make clean || true
		popd
		pushd $TOP_DIR/optee/optee_client
		make clean || true
		popd
		rm -rf $TOP_DIR/$OPTEE_OS_PATH/out
		PLATFORM=$SAVE_PLATFORM
	fi
}

do_package ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		local optee_plat_flavor=OPTEE_FLAVOUR
		export PLATFORM_FLAVOR=${!optee_plat_flavor}
		pushd $TOP_DIR/$OPTEE_OS_PATH
		mkdir -p ${OUTDIR}/$OPTEE_FLAVOUR
		cp out/arm-plat-${PLATFORM_FLAVOR}/core/${OPTEE_OS_BIN_NAME}  ${OUTDIR}/$PLATFORM/${OPTEE_OS_BIN_NAME}
		popd

		# optee client is independent of platform config,
		# packaging to plat independent location
		echo "packaging optee client.."
		mkdir -p ${OUTDIR}/optee/rootfs/usr/lib/
		mkdir -p ${OUTDIR}/optee/rootfs/usr/bin/
		pushd $TOP_DIR/optee/optee_client
		find out/ -name "*.so*" -exec cp {} ${OUTDIR}/optee/rootfs/usr/lib/ \;
		cp out/tee-supplicant/tee-supplicant ${OUTDIR}/optee/rootfs/usr/bin/
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
