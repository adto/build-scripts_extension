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

set -E

handle_error ()
{
	local callinfo=$(caller 0)
	local script=${callinfo##* }
	local lineno=${callinfo%% *}
	local func=${callinfo% *}
	func=${func#* }
	echo
	echo -en "${BOLD}${RED}Build failed: error while running ${func} at line "
	echo -en "${lineno} in ${script} for ${PLATFORM}[$FLAVOUR]"
	echo -e "[$FILESYSTEM_CONFIGURATION].${NORMAL}"
	echo
	exit 1
}

trap handle_error ERR

if [ "$PARALLELISM" != "" ]; then
	echo "Parallelism set in environment to $PARALLELISM, not overridding"
else
	PARALLELISM=`getconf _NPROCESSORS_ONLN`
fi

# Directory variables provided by the framework
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source $DIR/parse_params.sh
parse_params $@
set_formatting

pushd $DIR/..
TOP_DIR=`pwd`
popd
declare -i num_flavours
num_flavours=$(get_num_flavours $PLATFORM)
first_flavour_file=$(get_flavour_files $PLATFORM | head -n1)
first_flavour=$(basename $first_flavour_file)
if [ $num_flavours -eq 1 ] && [ "$first_flavour" = "$PLATFORM" ] ; then
	PLATDIR=${TOP_DIR}/output/$PLATFORM
else
	PLATDIR=${TOP_DIR}/output/$PLATFORM/$FLAVOUR
fi
OUTDIR=${PLATDIR}/components
LINUX_OUT_DIR=out/$PLATFORM/$COMPONENT_FLAVOUR

platform_folder="$DIR/configs/$PLATFORM"
if [ -z "$platform_folder" ] ; then
	echo -e "${BOLD}${RED}Could not find platform $PLATFORM.${NORMAL}"
	exit 2
fi
#Find flavours of the platform in question
if [ "$CMD" != "clean" ] && [ "$CMD" != "ignore" ] ; then
	check_not_missing "Flavour" $FLAVOUR
fi
flavour_file=$platform_folder/$FLAVOUR
if [ "$CMD" != "clean" ] && [ "$CMD" != "ignore" ]  && [ ! -f $flavour_file ] ; then
	echo -en "${BOLD}${RED}Couldn't find flavour $FLAVOUR for platform " >&2
	echo -e "$PLATFORM$NORMAL" >&2
	exit 2
fi

#Source the flavour file
if [ -f $flavour_file ] ; then
	source $flavour_file
elif [ "$CMD" = "clean" ] || [ "$CMD" = "ignore" ] ; then
	#We're cleaning so pick the first flavour otherwise we won't clean anything
	flavour_file=$(get_flavour_files $PLATFORM | head -n1)
	if [ ! -f $flavour_file ] ; then
		echo -en "$BOLD${RED}Attempted to run 'clean' without specifying" >&2
		echo -e " a flavour of platform." >&2
		echo -e "Couldn't find a valid flavour to clean.$NORMAL" >&2
		exit 3
	fi
	source $flavour_file
fi
#Source all applicable
for fs in $DIR/filesystems/$FILESYSTEM_CONFIGURATION ; do
	if [ ! -f $fs ] ; then
		echo -en "${BOLD}${RED}Couldn't find filesystem " >&2
		echo -e "$FILESYSTEM_CONFIGURATION${NORMAL}" >&2
		exit 2
	fi
	fs_name=$(basename $fs)
	if [[ $VALID_FILESYSTEMS == *"$fs_name"* ]] ; then
		source $fs
	else
		echo "Ignoring filesystem $fs_name for $PLATFORM[$FLAVOUR]"
	fi
done

# Optionally, override build options before build starts
if [ "$(type -t __do_override_build_configs)" == 'function' ]; then
	__do_override_build_configs
fi

case "$CMD" in
	"") do_build
	;;

	build) do_build
	;;

	clean) do_clean
	;;

	package) do_package
	;;

	ignore) echo "Parsing variant"
	;;

	*) simple_usage_exit 1
	;;
esac
