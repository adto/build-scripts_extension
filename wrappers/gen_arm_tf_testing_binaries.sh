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
# This script is used to perform the build for the FVP acceptance testing
# for ARM Trusted Firmware.
# The script calls the  build-all scripts using one of the fvp variants
# to establish the full software stack (most likely busybox), then it calls
# the build-arm-tf script with different arguements and moves the output to
# renamed directory according to the arguments passed.

set -e

# work out where we were called from
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

CONFIGS=$(echo Foundation_Rel{1..5} Base_Rel{1..10} Juno_Rel{1..5})
#Address that EL3 payloads will be loaded at
el3_address=0x80000000

declare -A ARMTF_DEBUG
ARMTF_DEBUG[Foundation_Rel1]=0
ARMTF_DEBUG[Foundation_Rel2]=0
ARMTF_DEBUG[Foundation_Rel3]=1
ARMTF_DEBUG[Foundation_Rel4]=1
ARMTF_DEBUG[Foundation_Rel5]=0
ARMTF_DEBUG[Base_Rel1]=0
ARMTF_DEBUG[Base_Rel2]=0
ARMTF_DEBUG[Base_Rel3]=1
ARMTF_DEBUG[Base_Rel4]=0
ARMTF_DEBUG[Base_Rel5]=1
ARMTF_DEBUG[Base_Rel6]=1
ARMTF_DEBUG[Base_Rel7]=1
ARMTF_DEBUG[Base_Rel8]=0
ARMTF_DEBUG[Base_Rel9]=1
ARMTF_DEBUG[Base_Rel10]=0
ARMTF_DEBUG[Juno_Rel1]=0
ARMTF_DEBUG[Juno_Rel2]=0
ARMTF_DEBUG[Juno_Rel3]=1
ARMTF_DEBUG[Juno_Rel4]=1
ARMTF_DEBUG[Juno_Rel5]=0

declare -A ARMTF_TBBR
ARMTF_TBBR[Foundation_Rel1]=1
ARMTF_TBBR[Foundation_Rel2]=0
ARMTF_TBBR[Foundation_Rel3]=1
ARMTF_TBBR[Foundation_Rel4]=1
ARMTF_TBBR[Foundation_Rel5]=1
ARMTF_TBBR[Base_Rel1]=1
ARMTF_TBBR[Base_Rel2]=0
ARMTF_TBBR[Base_Rel3]=1
ARMTF_TBBR[Base_Rel4]=1
ARMTF_TBBR[Base_Rel5]=1
ARMTF_TBBR[Base_Rel6]=0
ARMTF_TBBR[Base_Rel7]=1
ARMTF_TBBR[Base_Rel8]=1
ARMTF_TBBR[Base_Rel9]=1
ARMTF_TBBR[Base_Rel10]=1
ARMTF_TBBR[Juno_Rel1]=1
ARMTF_TBBR[Juno_Rel2]=0
ARMTF_TBBR[Juno_Rel3]=1
ARMTF_TBBR[Juno_Rel4]=1
ARMTF_TBBR[Juno_Rel5]=1

declare -A ARMTF_FLAGS
ARMTF_FLAGS[Foundation_Rel1]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 FVP_USE_GIC_DRIVER=FVP_GICV3"
ARMTF_FLAGS[Foundation_Rel2]="PROGRAMMABLE_RESET_ADDRESS=1"
ARMTF_FLAGS[Foundation_Rel3]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 CRASH_REPORTING=1 ASM_ASSERTION=1 CTX_INCLUDE_FPREGS=1 HANDLE_EA_EL3_FIRST=1"
#Foundation_Rel4 can only be tested with TFTF as Linux does not recognise PSCI_EXTENDED_STATE_ID yet
ARMTF_FLAGS[Foundation_Rel4]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 PSCI_EXTENDED_STATE_ID=1 ARM_RECOM_STATE_ID_ENC=1"
ARMTF_FLAGS[Foundation_Rel5]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 USE_COHERENT_MEM=0 EL3_PAYLOAD_BASE=$el3_address"
ARMTF_FLAGS[Base_Rel1]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1"
#Base_Rel2 uses the "-C gicv3.gicv2_only" model flag.
ARMTF_FLAGS[Base_Rel2]="PL011_GENERIC_UART=1"
ARMTF_FLAGS[Base_Rel3]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 CRASH_REPORTING=1  ASM_ASSERTION=1 CTX_INCLUDE_FPREGS=1 HANDLE_EA_EL3_FIRST=1"
ARMTF_FLAGS[Base_Rel4]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 ERROR_DEPRECATED=1 FVP_USE_GIC_DRIVER=FVP_GICV3"
ARMTF_FLAGS[Base_Rel5]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 CRASH_REPORTING=1 ASM_ASSERTION=1 CTX_INCLUDE_FPREGS=1 HANDLE_EA_EL3_FIRST=1"
ARMTF_FLAGS[Base_Rel6]="RESET_TO_BL31=1"
ARMTF_FLAGS[Base_Rel7]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 CRASH_REPORTING=1 ASM_ASSERTION=1 CTX_INCLUDE_FPREGS=1 HANDLE_EA_EL3_FIRST=1"
ARMTF_FLAGS[Base_Rel8]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1"
#Base_Rel9 can only be tested with TFTF as Linux does not recognise PSCI_EXTENDED_STATE_ID yet
ARMTF_FLAGS[Base_Rel9]="SPD=tspd FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 PSCI_EXTENDED_STATE_ID=1 ARM_RECOM_STATE_ID_ENC=1"
#TODO change GICV3_LEGACY to GICV2 and turn on ERROR_DEPRECATED=1
ARMTF_FLAGS[Base_Rel10]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 FVP_USE_GIC_DRIVER=FVP_GICV3 ERROR_DEPRECATED=1 USE_COHERENT_MEM=0 EL3_PAYLOAD_BASE=$el3_address"
ARMTF_FLAGS[Juno_Rel1]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 ERROR_DEPRECATED=1"
ARMTF_FLAGS[Juno_Rel2]="PROGRAMMABLE_RESET_ADDRESS=1"
ARMTF_FLAGS[Juno_Rel3]="SPD=tspd ERROR_DEPRECATED=1 CRASH_REPORTING=1 ASM_ASSERTION=1 CTX_INCLUDE_FPREGS=1 HANDLE_EA_EL3_FIRST=1"
#Juno_Rel4 can only be tested with TFTF as Linux does not recognise PSCI_EXTENDED_STATE_ID yet
ARMTF_FLAGS[Juno_Rel4]="SPD=tspd ERROR_DEPRECATED=1 PSCI_EXTENDED_STATE_ID=1 ARM_RECOM_STATE_ID_ENC=1"
ARMTF_FLAGS[Juno_Rel5]="SPD=tspd NS_TIMER_SWITCH=1 TSP_INIT_ASYNC=1 TSP_NS_INTR_ASYNC_PREEMPT=1 ERROR_DEPRECATED=1 USE_COHERENT_MEM=0 EL3_PAYLOAD_BASE=$el3_address"

fvp_bl32_param="--tos-fw $DIR/../../output/components/fvp/tf-bl32.bin"
juno_bl32_param="--tos-fw $DIR/../../output/components/juno/tf-bl32.bin"
declare -A ARMTF_FIP_PARAMS
ARMTF_FIP_PARAMS[Foundation_Rel1]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Foundation_Rel2]=""
ARMTF_FIP_PARAMS[Foundation_Rel3]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Foundation_Rel4]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Foundation_Rel5]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel1]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel2]=""
ARMTF_FIP_PARAMS[Base_Rel3]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel4]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel5]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel6]=""
ARMTF_FIP_PARAMS[Base_Rel7]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel8]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel9]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Base_Rel10]="$fvp_bl32_param"
ARMTF_FIP_PARAMS[Juno_Rel1]="$juno_bl32_param"
ARMTF_FIP_PARAMS[Juno_Rel2]=""
ARMTF_FIP_PARAMS[Juno_Rel3]="$juno_bl32_param"
ARMTF_FIP_PARAMS[Juno_Rel4]="$juno_bl32_param"
ARMTF_FIP_PARAMS[Juno_Rel5]="$juno_bl32_param"

fvp_bl32_cert_param="--tos-fw-key-cert $DIR/../../output/components/fvp/bl32_key.crt --tos-fw-cert $DIR/../../output/components/fvp/bl32.crt"
juno_bl32_cert_param="--tos-fw-key-cert $DIR/../../output/components/juno/bl32_key.crt --tos-fw-cert $DIR/../../output/components/juno/bl32.crt"
declare -A ARMTF_TBBR_PARAMS
ARMTF_TBBR_PARAMS[Foundation_Rel1]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Foundation_Rel2]=""
ARMTF_TBBR_PARAMS[Foundation_Rel3]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Foundation_Rel4]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Foundation_Rel5]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel1]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel2]=""
ARMTF_TBBR_PARAMS[Base_Rel3]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel4]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel5]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel6]=""
ARMTF_TBBR_PARAMS[Base_Rel7]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel8]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel9]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Base_Rel10]="$fvp_bl32_cert_param"
ARMTF_TBBR_PARAMS[Juno_Rel1]="$juno_bl32_cert_param"
ARMTF_TBBR_PARAMS[Juno_Rel2]=""
ARMTF_TBBR_PARAMS[Juno_Rel3]="$juno_bl32_cert_param"
ARMTF_TBBR_PARAMS[Juno_Rel4]="$juno_bl32_cert_param"
ARMTF_TBBR_PARAMS[Juno_Rel5]="$juno_bl32_cert_param"

# move ourselves to build-scripts
pushd $DIR/..

#Backup the variant file
export VARIANT=css-mobile-busybox
#Most of core config is now in css-mobile
export VARIANT_FILE=variants/css-mobile
pwd
cp ${VARIANT_FILE}{,.original}

ALL_PLATFORMS="fvp juno foundation"
declare -A PLATFORM_TO_COMPONENT
PLATFORM_TO_COMPONENT[fvp]=fvp
PLATFORM_TO_COMPONENT[foundation]=fvp
PLATFORM_TO_COMPONENT[juno]=juno

unset WORKSPACE
./build-all.sh ${VARIANT} all
#Copy all relevent platform folders
for platfolder in $ALL_PLATFORMS ; do
	component=${PLATFORM_TO_COMPONENT[$platfolder]}
	if [[ -d ../output/components/$component ]] ; then
		mv ../output/components/$component ../output/components/$platfolder.original
	fi
	mv ../output/$platfolder ../output/$platfolder.original
done

for item in $CONFIGS; do
	echo " item : $item"
	if [[ "$item" == "Foundation"* ]] ; then
		plat=foundation
		armtf_plats=fvp
	elif [[ "$item" == "Base"* ]] ; then
		plat=fvp
		armtf_plats=fvp
	elif [[ "$item" == "Juno"* ]] ; then
		plat=juno
		armtf_plats=juno
	fi
	#Need to modify following params in the variant file
	#ARM_TF_DEBUG_ENABLED
	#ARM_TF_BUILD_FLAGS (actually no need as it's not in the variant file)
	#TARGET_${plat}[tbbr]

	#Restore Original Variant file
	cp ${VARIANT_FILE}{.original,}
	#Apply changes
	set -x
	sed -i 's/ARM_TF_DEBUG_ENABLED=.*/ARM_TF_DEBUG_ENABLED='${ARMTF_DEBUG[$item]}'/g' ${VARIANT_FILE}
	sed -i 's/TARGET_'$plat'\[tbbr\]=.*/TARGET_'$plat'[tbbr]='${ARMTF_TBBR[$item]}'/g' ${VARIANT_FILE}
	sed -i 's/ARM_TF_PLATS=.*/ARM_TF_PLATS='$armtf_plats'/g' ${VARIANT_FILE}
	sed -i 's/OPTEE_mobile\[optee\]=1/OPTEE_mobile[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/OPTEE_fvp\[optee\]=1/OPTEE_fvp[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/OPTEE_juno\[optee\]=1/OPTEE_juno[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/TARGET_fvp\[optee\]=1/TARGET_fvp[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/TARGET_juno\[optee\]=1/TARGET_juno[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/TARGET_juno\[optee\]=1/TARGET_juno[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/TARGET_armstrong\[optee\]=1/TARGET_armstrong[optee]=0/g' ${VARIANT_FILE}
	sed -i 's/TARGET_buzz\[optee\]=1/TARGET_buzz[optee]=0/g' ${VARIANT_FILE}
	#Cannot use sed, it doesn't appear in the Variant file
	echo "ARM_TF_BUILD_FLAGS=\"${ARMTF_FLAGS[$item]}\"" >> ${VARIANT_FILE}
	set +x
	export EXTRA_FIP_PARAM="${ARMTF_FIP_PARAMS[$item]}"
	export EXTRA_TBBR_PARAM="${ARMTF_TBBR_PARAMS[$item]}"

	#Copy back in original platform folders
	for platfolder in $ALL_PLATFORMS ; do
		component=${PLATFORM_TO_COMPONENT[$platfolder]}
		if [[ -d ../output/components/${component} ]] ; then
			rm -rf ../output/components/${component}
		fi
		if [[ -d ../output/components/${component}.original ]] ; then
			cp -r ../output/components/${component}.original ../output/components/${component}
		fi
		if [[ -d ../output/${platfolder} ]] ; then
			rm -rf ../output/${platfolder}
		fi
		cp -r ../output/${platfolder}.original ../output/${platfolder}
	done

	./build-arm-tf.sh ${VARIANT} clean
	echo "Building item: $item"
	./build-arm-tf.sh ${VARIANT} build
	./build-arm-tf.sh ${VARIANT} package

	./build-target-bins.sh ${VARIANT} package

	#Export the folder we need
	component=${PLATFORM_TO_COMPONENT[$plat]}
	mv ../output/components/${component} ../output/components/${component}.$item
	mv ../output/${plat} ../output/${plat}.$item

	# fix up the symlinks to point to the new output directory...
	pushd ../output/$plat.$item
	binaries=`ls tf*.bin`
	rm tf-*.bin
	for the_bin in $binaries; do
		ln -s ../components/${component}.$item/$the_bin $the_bin
	done
	popd
done

#Clear all originals first
for platfolder in $ALL_PLATFORMS ; do
	if [[ -d ../output/${platfolder} ]] ; then
		rm -rf ../output/${platfolder}
	fi
done

#Then copy over originals after their destinations are cleared
for platfolder in $ALL_PLATFORMS ; do
	component=${PLATFORM_TO_COMPONENT[$platfolder]}
	if [[ -d ../output/components/${component}.original ]] ; then
		mv ../output/components/${component}.original ../output/components/${component}
	fi
	mv ../output/${platfolder}.original ../output/${platfolder}
	pushd ../output/${platfolder}
	rm tf-*.bin
	for the_bin in $binaries; do
		ln -s ../components/${component}/$the_bin $the_bin
	done
	popd
done

#Clear any broken links
find ../output -xtype l -delete

#Restore the variant file
mv ${VARIANT_FILE}{.original,}
# return the caller to where they called from
popd

