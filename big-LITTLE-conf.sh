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

# select a kernel scheduling model from EAS or big-LITTLE-MP

# uses BL_SUPPORT
# uses LINUX_PATH

# if the user provides BL_SUPPORT="", we will leave that alone
# if the user provides incorrect case for EAS or big-LITTLE-MP, this will be corrected.
# if the user either does not define BL_SUPPORT or provides anything which doesn't match
#  one of EAS or big-LITTLE-MP, then we look to see what the kernel currently provides.
# if the kernel has big-LITTLE-MP, use it. If kernel has EAS, use that. Check is in that
#  order, so if both are present we will use big-LITTLE-MP.
# if the kernel doesn't have whatever resulted from the above process, we set BL_SUPPORT=""

# this script expects LINUX_PATH to already be set to point to the kernel
# source.
if [ -z "$LINUX_PATH" ] ; then
  echo "\$LINUX_PATH has not been set"
  exit
fi

modify_bl_config() {
    # these are the names of the config fragments in linux/linaro/configs
    BLMP_CONF="big-LITTLE-MP"
    EAS_CONF="EAS"
    ORIG_BL_SUPPORT="$BL_SUPPORT"
    # find out what is present in the currently checked-out kernel
    if [ -f "$LINUX_PATH/linaro/configs/EAS.conf" ] ; then
        KERNEL_CONF="$EAS_CONF"
    else
        KERNEL_CONF="$BLMP_CONF"
    fi

    # if nothing is defined, use EAS.conf if present or use big-LITTLE-MP
    if [ -z "$BL_SUPPORT" ] ; then
        if [ -f "$LINUX_PATH/linaro/configs/EAS.conf" ] ; then
            BL_SUPPORT="$EAS_CONF"
        else
            BL_SUPPORT="$BLMP_CONF"
        fi
    else
        # if the user did define something, make sure the case is correct.
        BLMP_CONF_UPPER=`echo $BLMP_CONF | tr '[a-z]' '[A-Z]'`
        EAS_CONF_UPPER=`echo $EAS_CONF | tr '[a-z]' '[A-Z]'`
        BL_SUPPORT_UPPER=`echo $BL_SUPPORT | tr '[a-z]' '[A-Z]'`
        if [ ! "$BL_SUPPORT_UPPER" = "$BLMP_CONF_UPPER" ] ; then
            if [ ! "$BL_SUPPORT_UPPER" = "$EAS_CONF_UPPER" ] ; then
                echo "WARNING: BL_SUPPORT was set to \"$BL_SUPPORT\". The current kernel provides $KERNEL_CONF. Overriding to $KERNEL_CONF"
                BL_SUPPORT="$KERNEL_CONF"
            else
                BL_SUPPORT="$EAS_CONF"
            fi
        else
            BL_SUPPORT="$BLMP_CONF"
        fi
    fi

    # now we definitely have either EAS_CONF or BLMP_CONF, ensure the files are there.
    if [ ! -f "$LINUX_PATH/linaro/configs/$BL_SUPPORT.conf" ] ; then
        echo "ERROR: Selected $BL_SUPPORT but your platform does not have this config."
        echo "You provided \$BL_SUPPORT=$ORIG_BL_SUPPORT, which I understood as requesting"
        echo "$BL_SUPPORT. However $LINUX_PATH/linaro/configs/ does not contain $BL_SUPPORT.conf"
        echo "Turning off BL_SUPPORT."
        BL_SUPPORT=""
    fi
}

if [ "$ENABLE_BL_CONFIG" == "1" ]; then
	# do nothing if the user has already defined it to be empty
	# but do the replacement if it is not.
	if [ -z ${BL_SUPPORT+x} ] ; then
	    modify_bl_config
	else
	    if [ -n "${BL_SUPPORT}" ] ; then
	        modify_bl_config
	    else
		echo "BL_SUPPORT was defined to be empty. Leaving it alone."
	    fi
	fi
fi
