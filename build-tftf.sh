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
# LINUX_COMPILER - PATH to GCC including CROSS-COMPILE prefix
# TFTF_BUILD_ENABLED - Flag to enable building ARM TFTF
# TFTF_PATH - sub-directory containing ARM TFTF code
# TFTF_PLATS - List of platforms to be built (from available in tftf/plat)
# TFTF_DEBUG_ENABLED - 1 = debug, 0 = release build
#

do_build ()
{
	if [ "$TFTF_BUILD_ENABLED" == "1" ]; then
		export CROSS_COMPILE=$TOP_DIR/$LINUX_COMPILER

		pushd $TOP_DIR/$TFTF_PATH
		for plat in $TFTF_PLATS; do
			make -j $PARALLELISM PLAT=${plat} DEBUG=${TFTF_DEBUG_ENABLED} TEST_REPORTS="${TFTF_REPORTS}"
		done
		popd
	fi
}

do_clean ()
{
	if [ "$TFTF_BUILD_ENABLED" == "1" ]; then
		export CROSS_COMPILE=$TOP_DIR/$LINUX_COMPILER

		pushd $TOP_DIR/$TFTF_PATH

		for plat in $TFTF_PLATS; do
			make PLAT=$plat DEBUG=$TFTF_DEBUG_ENABLED clean
		done
		popd
	fi
}

do_package ()
{
	if [ "$TFTF_BUILD_ENABLED" == "1" ]; then
		echo "Packaging tftf... $VARIANT";
		# Copy binaries to output folder
		for plat in $TFTF_PLATS; do
			mkdir -p ${OUTDIR}/$plat
			local mode=release
			if [ "$TFTF_DEBUG_ENABLED" == "1" ]; then
				mode=debug
			fi
			cp ${TOP_DIR}/${TFTF_PATH}/build/${plat}/${mode}/tftf.bin ${OUTDIR}/${plat}/
		done
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
