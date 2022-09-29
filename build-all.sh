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

set -e

# find the script directory...
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

__do_sort_scripts() {
	if [ "$FINAL_BUILD_STEP" != "" ]; then
		echo "Sorting the build scripts for correctness."
		echo $BUILD_SCRIPTS
		BUILD_SCRIPTS=`echo "$BUILD_SCRIPTS" | sed "s/$FINAL_BUILD_STEP/ /g"`
		BUILD_SCRIPTS=$BUILD_SCRIPTS$FINAL_BUILD_STEP
		echo $BUILD_SCRIPTS
		echo "Done."
	fi
}

__do_single_cmd() {
	local CMD=$1
	echo "***********************************"
	section_descriptor="$CMD for $build on $PLATFORM[$FLAVOUR][$FILESYSTEM_CONFIGURATION]"
	echo "Execute $section_descriptor"
	${DIR}/$build $@
	if [ "$?" -ne 0 ]; then
		echo -e "${BOLD}${RED}Command failed: $section_descriptor${NORMAL}"
		exit 1
	fi


	echo "Execute $section_descriptor done."
	echo "-----------------------------------"
}

__do_build_all_loop() {
	if [ -z "$FLAVOUR" ] ; then
		flavours=$(get_flavour_files $PLATFORM | tr '\n' ' ')
		FLAVOURS=""
		for flavour_file in $flavours ; do
			flavour_name=$(basename $flavour_file)
			if [ -z "$FLAVOURS" ] ; then
				FLAVOURS="$flavour_name"
			else
				FLAVOURS="$FLAVOURS $flavour_name"
			fi
		done
	else
		FLAVOURS=$FLAVOUR
	fi
	initial=1
	for flavour in $FLAVOURS ; do
		source $DIR/configs/$PLATFORM/$flavour
		#Source all applicable
		for fs in $DIR/filesystems/$FILESYSTEM_CONFIGURATION ; do
			if [ ! -f $fs ] ; then
				echo -en "${BOLD}${RED}Couldn't find filesystem " >&2
				echo -e "$FILESYSTEM_CONFIGURATION${NORMAL}" >&2
				exit 2
			fi
			source $fs
		done
		export FLAVOUR=$flavour
		__do_sort_scripts

		# Optionally, override build options before build starts
		if [ "$(type -t __do_override_build_configs)" == 'function' ]; then
			__do_override_build_configs
			export -f __do_override_build_configs
		fi

		if [ "$initial" = "1" ] ; then
			#For the first flavour clean and build all components.
			build_scripts=$BUILD_SCRIPTS
		else
			#For the other flavours build just the changed components
			build_scripts=$FLAVOUR_BUILD_SCRIPTS
		fi
		initial=0
		for build in $build_scripts ; do
			__do_single_cmd clean
			__do_single_cmd build
		done
		for build in $BUILD_SCRIPTS ; do
			__do_single_cmd package
		done
	done
}

__do_build_all()
{
	local CMD=$1
	SAVE_CMD=$CMD
	source $DIR/framework.sh ignore $@
	CMD=$SAVE_CMD
	if [ -z "$CMD" ] ; then
		CMD="build"
	fi
	__do_sort_scripts

	# Optionally, override build options before build starts
	if [ "$(type -t __do_override_build_configs)" == 'function' ]; then
		__do_override_build_configs
		export -f __do_override_build_configs
	fi

	# Now to execute each component build in turn
	for build in $BUILD_SCRIPTS; do
		__do_single_cmd $@
	done

	if [ "$CMD" = "clean" ]; then
		echo -e "${GREEN}Finishing clean by removing $OUTDIR and $PLATDIR${NORMAL}"
		rm -rf $OUTDIR
		rm -rf $PLATDIR
	fi
}

#Parse the arguments passed in from the command line
source $DIR/parse_params.sh
parse_params $@

if [ "$CMD" = "all" ] ; then
	__do_build_all_loop
else
	__do_build_all $CMD
fi

