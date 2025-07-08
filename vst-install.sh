#!/bin/bash
# Vesta installation wrapper
# http://vestacp.com

#
# Currently Supported Operating Systems:
#
#   RHEL 5, 6, 7
#   CentOS 5, 6, 7
#   Debian 7, 8
#   Ubuntu 12.04 - 24.04
#   Amazon Linux 2017
#

# Am I root?
if [ "x$(id -u)" != 'x0' ]; then
    echo 'Error: this script can only be executed by root'
    exit 1
fi

# Check admin user account
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ -z "$1" ]; then
    echo "Error: user admin exists"
    echo
    echo 'Please remove admin user before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo "Example: bash $0 --force"
    exit 1
fi

# Check admin group
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ -z "$1" ]; then
    echo "Error: group admin exists"
    echo
    echo 'Please remove admin group before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo "Example: bash $0 --force"
    exit 1
fi

# Detect OS
case $(head -n1 /etc/issue | cut -f 1 -d ' ') in
    Debian)     
        type="debian" 
        ;;
    Ubuntu)     
        type="ubuntu"
        # Get Ubuntu version
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            ubuntu_version="$VERSION_ID"
        else
            ubuntu_version=$(lsb_release -rs)
        fi
        echo "Detected Ubuntu version: $ubuntu_version"
        ;;
    Amazon)     
        type="amazon" 
        ;;
    *)          
        type="rhel" 
        ;;
esac

# Check wget
if [ -e '/usr/bin/wget' ]; then
    # For Ubuntu 22.04 or 24.04, use custom script
    if [ "$type" = "ubuntu" ] && ([ "$ubuntu_version" = "22.04" ] || [ "$ubuntu_version" = "24.04" ]); then
        wget https://raw.githubusercontent.com/waveban/vestacp/master/install/vst-install-ubuntu-2204.sh -O vst-install-$type.sh
    else
        # Default to official script for other versions
        wget http://vestacp.com/pub/vst-install-$type.sh -O vst-install-$type.sh
    fi
    
    if [ "$?" -eq '0' ]; then
        bash vst-install-$type.sh $*
        exit
    else
        echo "Error: vst-install-$type.sh download failed."
        exit 1
    fi
fi

# Check curl
if [ -e '/usr/bin/curl' ]; then
    # For Ubuntu 22.04 or 24.04, use custom script
    if [ "$type" = "ubuntu" ] && ([ "$ubuntu_version" = "22.04" ] || [ "$ubuntu_version" = "24.04" ]); then
        curl -o vst-install-$type.sh https://raw.githubusercontent.com/waveban/vestacp/master/install/vst-install-ubuntu-2204.sh
    else
        # Default to official script for other versions
        curl -O http://vestacp.com/pub/vst-install-$type.sh
    fi
    
    if [ "$?" -eq '0' ]; then
        bash vst-install-$type.sh $*
        exit
    else
        echo "Error: vst-install-$type.sh download failed."
        exit 1
    fi
fi

exit
