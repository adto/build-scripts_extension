#!/usr/bin/env bash

# Copyright (c) 2021, ARM Limited and Contributors. All rights reserved.
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
# to endorse or promote products derived from this software without
# specific prior written permission.
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

# this tool check if required host packages have been installed on support
# systems.
#
# exit code 0  - no dependency missing
# exit code !0 - dependency missing or unable to check

set -e
set -u

readonly DEPS_ubuntu_bionic=(
	"autoconf"
	"autopoint"
	"bc"
	"bison"
	"build-essential"
	"curl"
	"debianutils"
	"device-tree-compiler"
	"dosfstools"
	"flex"
	"gettext-base"
	"git"
	"libssl-dev"
	"m4"
	"mtools"
	"parted"
	"pkg-config"
	"python"
	"python3"
	"python3-distutils"
	"rsync"
	"unzip"
	"uuid-dev"
	"wget"
	"fuseext2"
)

readonly DIST_INFO=( $(lsb_release -ics) )
[[ -n "${DIST_INFO[*]}" ]] || exit 1

readonly DISTRIBUTION="${DIST_INFO[0],,}"
readonly CODENAME="${DIST_INFO[1],,}"
case "$DISTRIBUTION" in
	("ubuntu")
		deps="DEPS_ubuntu_$CODENAME"
		if ! [[ -v "$deps" ]] ; then
			echo "ERROR: Unknown Ubuntu: $CODENAME" >&2
			exit 1
		fi
		deps="$deps[@]"
		for dep in "${!deps}" ; do
			if ! LC_ALL=C dpkg-query --show -f='${Status}\n' "$dep" 2>/dev/null  | grep -qE '([[:blank:]]|^)installed([[:blank:]]|$)' ; then
				echo "$dep"
			fi
		done \
			| sort \
			| {
			mapfile -t missing_deps
		if [[ "${#missing_deps[@]}" -ne 0 ]] ; then
			echo "The following packages was detected as missing:"
			for s in "${missing_deps[@]}" ; do
				echo "  * $s"
			done
			echo
			echo "Install them with this commands:"
			echo "sudo apt-get install" "${missing_deps[@]}"
			exit 1
		fi
	}
	;;
(*)
	echo "ERROR: Unknown distribution, can not check dependencies!" >&2
	exit 1
esac
echo "no missing dependencies detected."
