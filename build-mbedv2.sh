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
# CROSS_COMPILE - PATH to Embedded GCC
# MBEDV2_BUILD_ENABLED - Flag to enable building mbed V2 code
# MBEDV2_PATH - sub-directory containing mbed V2 code
# MBEDV2_PLATS - List of platforms to be built
# MBEDV2_APPS - List of applications to be built for each platform
#

do_build ()
{
	if [ "$MBEDV2_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$MBEDV2_PATH/workspace_tools

		export CROSS_COMPILE=$CROSS_COMPILE

		for app in $MBEDV2_APPS; do
			for plat in $MBEDV2_PLATS; do
				python build.py -m $plat -t GCC_ARM -j $PARALLELISM
				python make.py -m $plat -t GCC_ARM -n $app -j $PARALLELISM
				python project.py -m $plat -i gcc_arm -n $app
			done
		done

		popd
	fi
}

do_clean ()
{
	if [ "$MBEDV2_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$MBEDV2_PATH/build
		# The "python build.py -c" option seems to just rebuild rather than
		# clean so clean for plats manually
		for plat in $MBEDV2_PLATS; do
			rm -rf mbed/TARGET_$plat
			rm -rf test/$plat
			rm -f export/*$plat.zip
		done

		popd
	fi
}

do_package ()
{
	if [ "$MBEDV2_BUILD_ENABLED" == "1" ]; then
		echo "Packaging mbed V2... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR

		for plat in $MBEDV2_PLATS; do
			mkdir -p ${OUTDIR}/$plat
			cp $TOP_DIR/$MBEDV2_PATH/build/export/*$plat.zip ${OUTDIR}/$plat/.
		done

		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
