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

#Print the script that the user explicitly called.
get_root_script() {
	declare -i depth
	depth=0
	while [ ! -z "$(caller $depth)" ] ; do
		depth=$depth+1
	done
	depth=$depth-1
	local callinfo=$(caller $depth)
	local script=${callinfo##* }
	echo $script
}

get_shell_type() {
	tty -s && echo "INTERACTIVE" || echo "NON-INTERACTIVE"
}

set_formatting() {
	if [ "$(get_shell_type)" = "INTERACTIVE" ] ; then
		export BOLD="\e[1m"
		export NORMAL="\e[0m"
		export RED="\e[31m"
		export GREEN="\e[32m"
		export YELLOW="\e[33m"
		export BLUE="\e[94m"
		export CYAN="\e[36m"
	fi
}

get_platform_dirs() {
	find $DIR/configs/ -mindepth 1 -maxdepth 1 -type d \
		| grep -v -e "common\$" -e "\/\."
}

get_num_platforms() {
	get_platform_dirs | wc -l
}

#Requires PLATFORM as a parameter
get_flavour_files() {
	if [ "$1" == "all" ] ; then
		return
	fi
	find $DIR/configs/$1 -mindepth 1 -maxdepth 1 -type f \
		| grep -v -e "$DIR/configs/$1/\." -e "\.base"
}

#Requires PLATFORM as a parameter
get_num_flavours() {
	get_flavour_files $1 | wc -l
}

get_filesystem_files() {
	find $DIR/filesystems -mindepth 1 -maxdepth 1 -type f \
		| grep -v -e "^\."
}

get_num_filesystems() {
	get_filesystem_files | wc -l
}

#If missing the platform, and there's only one platform, use that
#If missing the platform, and there's many platforms, show a warning but then
#continue to build everything
set_default_platform() {
	declare -i no_platforms
	no_platforms=$(get_num_platforms)
	if [ $no_platforms -eq 1 ] ; then
		plat=$(get_platform_dirs)
		PLATFORM=$(basename $plat)
	fi
	if [ -z "$PLATFORM" ] ; then
		set_formatting
		echo -e "${RED}Could not deduce which platform to build.${NORMAL}"
		echo -e "${RED}Proceeding to build all available platforms.${NORMAL}"
		if [ "$(get_shell_type)" = "INTERACTIVE" ] ; then
			sleep 5
		fi
		PLATFORM="all"
	fi
}

print_fs() {
	echo -en "<fileystems>: $BOLD${BLUE}"
	for fs_file in $(find $DIR/filesystems -mindepth 1 -maxdepth 1 -type f) ; do
		echo -n "$(basename $fs_file)|"
	done
	echo -e "${BOLD}all$NORMAL"
	echo -en "${BLUE}<filesystem>$NORMAL can be set to 'all' to build all "
	echo -e "filesystems available."
}

#Print a simple usage case for the event when this is being used from a generated
#release. However, it can appear with multiple platforms and will be more confusing.
simple_usage_exit() {
	set_formatting
	local flavour_cmd_list="clean/build/package"
	if [[ "$(get_root_script)" == *"build-all.sh" ]] ; then
		flavour_cmd_list="$flavour_cmd_list/all"
	fi
	echo -e "${BOLD}Usage:"
	if [[ "$(get_num_filesystems)" == "1" ]] ; then
		local fs_arg=""
	else
		local fs_arg="${BLUE}-f <filesystem>${NORMAL}"
	fi
	echo -en "	$0 $fs_arg "
	echo -e "${CYAN}$flavour_cmd_list${NORMAL}"
	if [[ "$(get_num_filesystems)" != "1" ]] ; then
		print_fs
	fi
	echo "For in depth help, please run: $0 -g"
	exit $1
}

#Print usage and exit with given return code
usage_exit ()
{
	#Show extra formatting if it's an interactive session
	#(but non in automated build systems as logging gets confusing)
	set_formatting
	local flavour_cmd_list="clean/build/package"
	if [[ "$(get_root_script)" == *"build-all.sh" ]] ; then
		flavour_cmd_list="$flavour_cmd_list/all"
	fi
	echo -e "${BOLD}Usage: ${NORMAL}"
	declare -i num_plats
	num_plats=$(get_num_platforms)
	if [ $num_plats -eq 1 ] ; then
		#If there's only one platform, then -p flag is optional
		echo -en "	$0 ${RED}[-p <platform>]${NORMAL} ${GREEN}-t <flavour>${NORMAL} ${YELLOW}-a <true/false>${NORMAL} "
	else
		#If not just one platform, -p flag is required.
		echo -en "	$0 ${RED}-p <platform>${NORMAL} ${GREEN}-t <flavour>${NORMAL} ${YELLOW}-a <true/false>${NORMAL} "
	fi
	echo -e "${BLUE}-f <filesystem>${NORMAL} ${CYAN}$flavour_cmd_list${NORMAL}"
	echo -e "$extra_message"
	plat_list=""
	for plat in $(get_platform_dirs) ; do
		if [ -z "$plat_list" ] ; then
			plat_list="${RED}$(basename $plat)${NORMAL}"
		else
			plat_list="$plat_list|${RED}$(basename $plat)${NORMAL}"
		fi
	done
	echo -e "<platform>: $plat_list|${RED}${BOLD}all${NORMAL}"
	echo "Valid platforms and flavours:"
	for platform_dir in $(get_platform_dirs) ; do
		platform=$(basename $platform_dir)
		flavours=$(get_flavour_files $platform)
		flavour_names=""
		for flavour in $flavours; do
			flavour_names="$flavour_names $(basename $flavour)"
		done
		if [ ! -z "$flavours" ] ; then
			declare -i num_flavs
			num_flavs=$(get_num_flavours $platform)
			first_flavour_file=$(get_flavour_files $platform | head -n1)
			first_flavour=$(basename $first_flavour_file)
			if [ $num_flavs -eq 1 ] && [ "$first_flavour" = "$platform" ]; then
				#This means that for platforms that have one flavour, named the same,
				#like juno, don't bother showing the flavour at all.
				echo -e "Platform configure$RED$platform$NORMAL has no flavours."
			else
				echo -e "Platform $BOLD$RED$platform$NORMAL has flavours $BOLD$GREEN$flavour_names$NORMAL"
			fi
		fi
	done
	echo
	echo -en "Valid fileystems: $BOLD${BLUE}"
	for fs_file in $(get_filesystem_files) ; do
		echo -n "$(basename $fs_file) "
	done
	echo -e "$NORMAL"
	echo -en "${BLUE}FILESYSTEM$NORMAL can be set to 'all' to build all "
	echo -e "filesystems available."
	echo
	echo -e "${YELLOW}-a option:${NORMAL}"
	echo -e "	This option is used when using FVP_Base_AEMv8A-AEMv8A model that doesn't has PCI & SMMU IPs."
	echo -e "	Pass -a true for FVP_Base_AEMv8A-AEMv8A model which disables PCI & SMMU nodes in device tree."
	echo -e "	Can be ignored for FVP_Base_RevC-2xAEMv8A model."
	echo
	echo -e "${CYAN}Commands:${NORMAL}"
	echo -e "	${CYAN}clean${NORMAL}	 Cleans any binaries produced during build command."
	echo -e "	${CYAN}build${NORMAL}	 Build source."
	echo -e "	${CYAN}package${NORMAL}	 Packages into output folder for use."
	echo -e "		 Must be done after build command."
	if [[ "$(get_root_script)" == *"build-all.sh" ]] ; then
		echo -e "	${CYAN}all${NORMAL}	 Does a build and package for any flavours specified."
	fi
	exit $1
}


check_not_missing() {
	local description=$1
	local value=$2
	if [ -z "$value" ] ; then
		echo -e "$BOLD$RED$description is not set.$NORMAL" >&2
		simple_usage_exit 1
	fi
}

parse_params() {
	#If this is called multiple times, let's ensure that it's handled
	unset OPTIND
	unset CMD

	#Parse the named parameters
	while getopts "p:f:a:hgt:d" opt; do
		case $opt in
			p)
				export PLATFORM="$OPTARG"
				;;
			f)
				export FILESYSTEM_CONFIGURATION="$OPTARG"
				;;
			t)
				export FLAVOUR="$OPTARG"
				;;
			a)
				export AEMV8A="$OPTARG"
				;;
			d)
				source $PARSE_PARAMS_DIR/.debug
				;;
			h)
				simple_usage_exit 0
				;;
			g)
				usage_exit 0
				;;
			\?)
				simple_usage_exit 1
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	export CMD=${@:$OPTIND:1}

	if [ -z "$CMD" ] ; then
		set_formatting
		echo -e "${RED}No command given.${NORMAL}"
		simple_usage_exit 1
	fi

	if [ "$FILESYSTEM_CONFIGURATION" = "all" ] ; then
		FILESYSTEM_CONFIGURATION='*'
	fi

	if [ -z "$PLATFORM" ] ; then
		set_default_platform
	fi

	CUR_DIR=`pwd`
	DTS_FILE=$CUR_DIR/linux/arch/arm64/boot/dts/arm/fvp-base-aemv8a-aemv8a.dts
	DTSI_FILE=$CUR_DIR/linux/arch/arm64/boot/dts/arm/fvp-base-aemv8a-aemv8a.dtsi
	if [ -f "$DTS_FILE" ] ; then
		CNT=$(grep "delete-node" $DTS_FILE | wc -l)
		CNTI=$(grep "pci" $DTSI_FILE | wc -l)
		if [ "$AEMV8A" = "true" ] ; then
			if [ "$CNTI" != "0" ] && [ "$CNT" = "0" ] ; then
				sed -i -e "\$a/delete-node/&{/pci@40000000};" $DTS_FILE
				sed -i -e "\$a/delete-node/&{/smmu@2b400000};" $DTS_FILE
			elif [ "$CNTI" = "0" ] && [ "$CNT" != "0" ] ; then
				sed -i '/delete-node/d' $DTS_FILE
			fi
		else
			if [ "$CNT" != "0" ] ; then
				sed -i '/delete-node/d' $DTS_FILE
			fi
		fi
	fi

	if [ -z "$FLAVOUR" ] ; then
		set_formatting
		#If there's one flavour, use it
		declare -i num_flavours
		num_flavours=$(get_num_flavours $PLATFORM)
		if [ $num_flavours -eq 1 ] ; then
			flav_file=$(get_flavour_files $PLATFORM)
			FLAVOUR=$(basename $flav_file)
		else
			echo -e "${RED}Could not deduce which flavour to build.${NORMAL}"
			echo -e "${RED}Proceeding to build all available flavours${NORMAL}"
		fi
	fi

	loop=0
	if [ -z "$FILESYSTEM_CONFIGURATION" ] ; then
		declare -i num_fs
		num_fs=$(get_num_filesystems)
		if [ $num_fs -eq 1 ] ; then
			fs_file=$(get_filesystem_files)
			FILESYSTEM_CONFIGURATION=$(basename $fs_file)
		else
			set_formatting
			echo -e "${RED}Could not deduce which filesystem to build.${NORMAL}"
			echo -e "${RED}Proceeding to build all available filesystems${NORMAL}"
			FILESYSTEM_CONFIGURATION="*"
		fi
	fi

	if [ -z "$FLAVOUR" ] || [ "$FLAVOUR" = "all" ] ; then
		#Flavour looping is done elsewhere if FLAVOUR is not set.
		unset FLAVOUR
	fi

	#If all platforms, loop over the platforms
	if [ -z "$PLATFORM" ] || [ "$PLATFORM" = "all" ] ; then
		set_formatting
		platform_loop=""
		for platform_dir in $(get_platform_dirs) ; do
			flavours=$(ls $platform_dir | grep -v '.base$'| tr '\n' ' ')
			#Don't build platforms with no flavours
			if [ ! -z "$flavours" ] ; then
				platform_name=$(basename $platform_dir)
				platform_loop="$platform_loop $platform_name"
			fi
		done
		if [ "$CMD" = "all" ] ; then
			action=Building
		else
			action=Cleaning
		fi
		echo -e "${BOLD}$action for all platforms: ${platform_loop}${NORMAL}"
		if [ "$(get_shell_type)" = "INTERACTIVE" ] ; then
			sleep 5
		fi
		for platform_entry in $platform_loop ; do
			#HACK Disable IOT for now.
			if [ "$platform_entry" = "css-iot" ] ; then
				continue
			fi
			$(get_root_script) -p $platform_entry $CMD
		done
		if [ "$CMD" = "clean" ] ; then
			this_dir=$(dirname $(get_root_script))
			entire_output=$(readlink -f ${this_dir}/../output)
			echo -e "${GREEN}Finishing clean by removing $entire_output${NORMAL}"
			rm -rf $entire_output
		fi
		exit 0
	fi
}
export PARSE_PARAMS_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
