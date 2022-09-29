## @file
#
#  Copyright 2006 - 2010 Unified EFI, Inc.<BR>
#  Copyright (c) 2010, Intel Corporation. All rights reserved.<BR>
#  Copyright (c) 2018, ARM Limited. All rights reserved.<BR>
#
#  This program and the accompanying materials
#  are licensed and made available under the terms and conditions of the BSD License
#  which accompanies this distribution.  The full text of the license may be found at
#  http://opensource.org/licenses/bsd-license.php
#
#  THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
#  WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
#
##
#/*++
#

# Module Name:
#
#   SctStartup.nsh
#
# Abstract:
#
#   Startup script for EFI SCT automation

#--*/

#
# NOTE: The file system name is hard coded since it is not clear on how to get the
# file system name in the script.
#

echo -off

for %i in 0 1 2 3 4 5 6 7 8 9 A B C D E F
  if exist FS%i:\Sct then
    #
    # Found EFI SCT harness
    #
    FS%i:
    cd Sct

    echo Press any key to stop the EFI SCT running

    stallforkey.efi 5
    if %lasterror% == 0 then
      goto Done
    endif

	if exist FS%i:\Sct\Sequence\sct.seq then
		Sct -v -s sct.seq
	else
		Sct -v -c
	endif

	Sct -g results.csv

	echo UEFI-SCT Done!

    goto Done
  endif
endfor

:Done
