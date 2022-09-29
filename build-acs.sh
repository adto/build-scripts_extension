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

# Environment variables
WS_DIR=`pwd`
ACS_SOURCE_PATH=validation/sys-test/arm-enterprise-acs/
ACS_OUT_PATH=validation/sys-test/arm-enterprise-acs/luv/build
LUVFILE=$WS_DIR/$ACS_SOURCE_PATH/luv/build_luvos.sh
ACS_OUTPUT_FILE=$WS_DIR/$ACS_OUT_PATH/tmp/deploy/images/qemuarm64/luv-live-image-gpt.img

do_clean () {
	#remove the ACS build directory
	if [ -d "$WS_DIR/$ACS_OUT_PATH" ]; then
		pushd $WS_DIR/$ACS_SOURCE_PATH
		rm -Rf luv/build
		popd
	fi

	#remove the luv-live image file
	if [ -f "$WS_DIR/output/$PLATFORM/luv-live-image-gpt.img" ]; then
		rm -f "$WS_DIR/output/$PLATFORM/luv-live-image-gpt.img"
	fi
}

do_build () {
	echo "Build Arm Architecture Compliance Suite (ACS) ......."
	if [ -d "$WS_DIR/$ACS_SOURCE_PATH" ]; then
		pushd $WS_DIR/$ACS_SOURCE_PATH
		#Download the LuvOS repository and apply the patches
		if [ -e "$LUVFILE" ]; then
			:
		else
			./acs_sync.sh
		fi
		pushd luv
		#luvos build expect to run with umask 022
		umask 022
		#Build SBSA/SBBR binaries, SBBR (excluding UEFI-SCT)
		echo "You must be a member of https://github.com/UEFI/UEFI-SCT for SCT tests"
		echo "as your username and password will be required"
		echo "skipping the UEFI-SCT tests.."
		./build_luvos.sh
		#back to build_dir- popd
		popd
	else
		echo "[${FG_YELLOW}Error${FG_DEFAULT}] ACS source not found!"
		exit 1;
	fi
}

do_package () {
	#create folder under output/validation
	if [ -f $ACS_OUTPUT_FILE ]; then
		echo "Packaging ACS for $PLATFORM"
		cp $ACS_OUTPUT_FILE $WS_DIR/output/$PLATFORM/
	else
		echo "Packaging ACS failed for $PLATFORM"
		exit 1
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
