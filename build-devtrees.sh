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
# DEVTREE_BUILD_ENABLED - Flag to enable building Device Trees
# DEVTREE_PATH - sub-directory containing Device Tree source files
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
#	fdts - the fdt pattern used by the platform
# LINUX_PATH - Path to Linux tree containing DT compiler and include files
# LINUX_OUT_DIR - output directory name
# LINUX_CONFIG_DEFAULT - the default linux build output

do_build ()
{
	if [ "$DEVTREE_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$DEVTREE_PATH ]; then
			pushd $TOP_DIR/$DEVTREE_PATH
			for plat in $TARGET_BINS_PLATS; do
				local target=TARGET_$plat[fdts]
				for item in ${!target}; do
					if [ -f ${item}.dts ]; then
						echo ${item}
						${CROSS_COMPILE}cpp -I$TOP_DIR/$LINUX_PATH/include -x assembler-with-cpp -o $item.pre $item.dts
						sed -i '/stdc-predef.h/d' $item.pre
						$TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR/$LINUX_CONFIG_DEFAULT/scripts/dtc/dtc -O dtb -o $item.dtb -i $item.dts -b 0 $item.pre
					else
						echo "skipping linux dts file ${item}.dts"
					fi
				done
			done
			popd
		fi
	fi
}

do_clean ()
{
	if [ "$DEVTREE_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$DEVTREE_PATH ]; then
			pushd $TOP_DIR/$DEVTREE_PATH
			rm -f *.dtb *.pre
			popd
		fi
	fi
}

do_package ()
{
	if [ "$DEVTREE_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$DEVTREE_PATH ]; then
			echo "Packaging Devtrees... $VARIANT";
			# Copy binary to output folder - put in Linux folder
			pushd $TOP_DIR/$DEVTREE_PATH
			mkdir -p ${OUTDIR}/$LINUX_PATH
			for plat in $TARGET_BINS_PLATS; do
				local fd=TARGET_$plat[fdts]
				for target in ${!fd}; do
					for item in $target; do
						if [ -f ${item}.dts ]; then
							echo ${item}
							cp $item.dtb ${OUTDIR}/$LINUX_PATH/.
							cp $item.dtb ${OUTDIR}/$PLATFORM/.
						else
							echo "skipping linux ${item}.dts file"
						fi
					done
				done
			done
			popd
		fi
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
