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

declare -A arm_platforms
arm_platforms[sgi575]=1
arm_platforms[rdn1edge]=1

# Environment variables
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
WS_DIR=`pwd`

__print_supported_arm_platforms()
{
	echo "Supported platforms are -"
	for plat in "${!arm_platforms[@]}" ;
		do
			printf "\t $plat \n"
		done
	echo
}

__print_usage()
{
	echo "Usage: ./build-scripts/build-test-tftf.sh -p <platform> <command>"
	echo
	echo "build-test-tftf.sh: Builds the platform software stack with all the"
	echo "required software components that allows the execution for TF-A"
	echo "tests on the platform."
	echo
	__print_supported_arm_platforms
	echo "Supported build commands are - clean/build/package/all"
	echo
	echo "Example 1: ./build-scripts/build-test-tftf.sh -p sgi575 all"
	echo "   This command builds the software stack for sgi575 platform and the"
	echo "   TF-A source code and prepares the FIP image for TF-A tests."
	echo
	echo "Example 1: ./build-scripts/build-test-tftf.sh -p sgi575 clean"
	echo "   This command cleans the previous build of the sgi575 platform software"
	echo "   stack and TF-A."
	echo
	exit
}

#callback from build-all.sh to override any build config
__do_override_build_configs()
{
	echo "build-test-tftf.sh: overriding default build configurations"
	BUILD_SCRIPTS="build-scp.sh build-arm-tf.sh build-tftf.sh build-target-bins.sh"
	ARM_TF_BUILD_FLAGS="RAS_EXTENSION=0 ENABLE_SPM=0 SDEI_SUPPORT=0 EL3_EXCEPTION_HANDLING=0 HANDLE_EA_EL3_FIRST=0"
	UEFI_BUILD_ENABLED=0
	UEFI_MM_BUILD_ENABLED=0
	TFTF_BUILD_ENABLED=1
}

parse_params() {
	#Parse the named parameters
	while getopts "p:" opt; do
		case $opt in
			p)
				ARM_PLATFORM="$OPTARG"
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	BUILD_CMD=${@:$OPTIND:1}

	#Ensure that the platform is supported
	if [ -z "$ARM_PLATFORM" ] ; then
		__print_usage
	fi
	if [ -z "${arm_platforms[$ARM_PLATFORM]}" ] ; then
		echo "[ERROR] Could not deduce which platform to build."
		__print_supported_arm_platforms
		exit
	fi

	#Ensure a build command is specified
	if [ -z "$BUILD_CMD" ] ; then
		__print_usage
	fi
}

#parse the command line parameters
parse_params $@

#override the command line parameters for build-all.sh
set -- "-p $ARM_PLATFORM -f none $BUILD_CMD"
source ./build-scripts/build-all.sh
