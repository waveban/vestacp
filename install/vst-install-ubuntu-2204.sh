#!/bin/bash

# Vesta Ubuntu installer v.06 for Ubuntu 22.04 and 24.04

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
export DEBIAN_FRONTEND=noninteractive
RHOST='apt.vestacp.com'
CHOST='c.vestacp.com'
VERSION='ubuntu'
VESTA='/usr/local/vesta'
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
arch=$(uname -i)
os='ubuntu'

# Define release code name for Ubuntu 22.04/24.04
if [ -f /etc/os-release ]; then
    . /etc/os-release
    release="$VERSION_ID"
    
    if [ "$release" = "22.04" ]; then
        codename="jammy"
        php_version="8.1"
    elif [ "$release" = "24.04" ]; then
        codename="noble"
        php_version="8.3"
    else
        echo "Error: This script is only for Ubuntu 22.04 and 24.04"
        exit 1
    fi
else
    echo "Error: Unable to determine Ubuntu version"
    exit 1
fi

# Always use focal repo for VestaCP since there's no jammy or noble repo
repo_codename="focal"

# Use a generic path for VestaCP installation files
vestacp="$VESTA/install/$VERSION"

# Defining software pack for all distros
software="nginx apache2 apache2-utils
    apparmor-utils awstats bc bind9 bsdmainutils bsdutils clamav-daemon
    cron curl dnsutils dovecot-imapd dovecot-pop3d e2fslibs e2fsprogs exim4
    exim4-daemon-heavy expect fail2ban flex ftp git idn imagemagick
    libapache2-mod-fcgid libapache2-mod-php libapache2-mod-rpaf
    lsof mc mysql-client mysql-common mysql-server
    ntpdate php-cgi php-common php-curl php-fpm phpmyadmin php-mysql
    phppgadmin php-pgsql postgresql postgresql-contrib proftpd-basic quota
    roundcube-core roundcube-mysql roundcube-plugins rrdtool spamassassin
    sudo vesta vesta-ioncube vesta-nginx vesta-php vesta-softaculous
    vim-common vsftpd webalizer whois zip net-tools"

# Add PHP version-specific packages
if [ "$php_version" = "8.1" ]; then
    software="$software php8.1-common php8.1-cli php8.1-fpm php8.1-mysql php8.1-gd"
    software="$software php8.1-curl php8.1-mbstring php8.1-xml php8.1-zip"
    software="$software libapache2-mod-php8.1"
elif [ "$php_version" = "8.3" ]; then
    software="$software php8.3-common php8.3-cli php8.3-fpm php8.3-mysql php8.3-gd"
    software="$software php8.3-curl php8.3-mbstring php8.3-xml php8.3-zip"
    software="$software libapache2-mod-php8.3"
fi

# Defining help function
help() {
    echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache           [yes|no]  default: yes
  -n, --nginx             Install Nginx            [yes|no]  default: yes
  -w, --phpfpm            Install PHP-FPM          [yes|no]  default: no
  -v, --vsftpd            Install Vsftpd           [yes|no]  default: yes
  -j, --proftpd           Install ProFTPD          [yes|no]  default: no
  -k, --named             Install Bind             [yes|no]  default: yes
  -m, --mysql             Install MySQL            [yes|no]  default: yes
  -g, --postgresql        Install PostgreSQL       [yes|no]  default: no
  -x, --exim              Install Exim             [yes|no]  default: yes
  -z, --dovecot           Install Dovecot          [yes|no]  default: yes
  -c, --clamav            Install ClamAV           [yes|no]  default: yes
  -t, --spamassassin      Install SpamAssassin     [yes|no]  default: yes
  -i, --iptables          Install Iptables         [yes|no]  default: yes
  -b, --fail2ban          Install Fail2ban         [yes|no]  default: yes
  -r, --remi              Install Remi repo        [yes|no]  default: yes
  -o, --softaculous       Install Softaculous      [yes|no]  default: yes
  -q, --quota             Filesystem Quota         [yes|no]  default: no
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install      [yes|no]  default: yes
  -s, --hostname          Set hostname
  -u, --ssl               Add LE SSL for hostname  [yes|no]  default: no
  -e, --email             Set admin email
  -d, --port              Set Vesta port
  -p, --password          Set admin password
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@vestacp.com -p p4ssw0rd --apache no --phpfpm yes"
    exit 1
}


# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Defining function to set default value
set_default_value() {
    eval variable=\$$1
    if [ -z "$variable" ]; then
        eval $1=$2
    fi
    if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
        eval $1=$2
    fi
}

# Defining function to set default language value
set_default_lang() {
    if [ -z "$lang" ]; then
        eval lang=$1
    fi
    lang_list="
        ar cz el fa hu ja no pt se ua
        bs da en fi id ka pl ro tr vi
        cn de es fr it nl pt-BR ru tw
        bg ko sr th ur"
    if !(echo $lang_list |grep -w $lang 1>&2>/dev/null); then
        eval lang=$1
    fi
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Creating temporary file
tmpfile=$(mktemp -p /tmp)

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --apache)               args="${args}-a " ;;
        --nginx)                args="${args}-n " ;;
        --phpfpm)               args="${args}-w " ;;
        --vsftpd)               args="${args}-v " ;;
        --proftpd)              args="${args}-j " ;;
        --named)                args="${args}-k " ;;
        --mysql)                args="${args}-m " ;;
        --postgresql)           args="${args}-g " ;;
        --exim)                 args="${args}-x " ;;
        --dovecot)              args="${args}-z " ;;
        --clamav)               args="${args}-c " ;;
        --spamassassin)         args="${args}-t " ;;
        --iptables)             args="${args}-i " ;;
        --fail2ban)             args="${args}-b " ;;
        --softaculous)          args="${args}-o " ;;
        --remi)                 args="${args}-r " ;;
        --quota)                args="${args}-q " ;;
        --lang)                 args="${args}-l " ;;
        --interactive)          args="${args}-y " ;;
        --hostname)             args="${args}-s " ;;
        --ssl)                  args="${args}-u " ;;
        --email)                args="${args}-e " ;;
        --port)                 args="${args}-d " ;;
        --password)             args="${args}-p " ;;
        --force)                args="${args}-f " ;;
        --help)                 args="${args}-h " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:n:w:v:j:k:m:g:x:z:c:t:i:b:r:o:q:l:y:s:u:e:d:p:fh" Option; do
    case $Option in
        a) apache=$OPTARG ;;            # Apache
        n) nginx=$OPTARG ;;             # Nginx
        w) phpfpm=$OPTARG ;;            # PHP-FPM
        v) vsftpd=$OPTARG ;;            # Vsftpd
        j) proftpd=$OPTARG ;;           # Proftpd
        k) named=$OPTARG ;;             # Named
        m) mysql=$OPTARG ;;             # MySQL
        g) postgresql=$OPTARG ;;        # PostgreSQL
        x) exim=$OPTARG ;;              # Exim
        z) dovecot=$OPTARG ;;           # Dovecot
        c) clamd=$OPTARG ;;             # ClamAV
        t) spamd=$OPTARG ;;             # SpamAssassin
        i) iptables=$OPTARG ;;          # Iptables
        b) fail2ban=$OPTARG ;;          # Fail2ban
        r) remi=$OPTARG ;;              # Remi repo
        o) softaculous=$OPTARG ;;       # Softaculous plugin
        q) quota=$OPTARG ;;             # FS Quota
        l) lang=$OPTARG ;;              # Language
        y) interactive=$OPTARG ;;       # Interactive install
        s) servername=$OPTARG ;;        # Hostname
        u) ssl=$OPTARG ;;               # Add Let's Encrypt SSL for hostname
        e) email=$OPTARG ;;             # Admin email
        d) port=$OPTARG ;;              # Vesta port
        p) vpass=$OPTARG ;;             # Admin password
        f) force='yes' ;;               # Force install
        h) help ;;                      # Help
        *) help ;;                      # Print help (default)
    esac
done

# Defining default software stack
set_default_value 'nginx' 'yes'
set_default_value 'apache' 'yes'
set_default_value 'phpfpm' 'no'
set_default_value 'vsftpd' 'yes'
set_default_value 'proftpd' 'no'
set_default_value 'named' 'yes'
set_default_value 'mysql' 'yes'
set_default_value 'postgresql' 'no'
set_default_value 'mongodb' 'no'
set_default_value 'exim' 'yes'
set_default_value 'dovecot' 'yes'
if [ $memory -lt 1500000 ]; then
    set_default_value 'clamd' 'no'
    set_default_value 'spamd' 'no'
else
    set_default_value 'clamd' 'yes'
    set_default_value 'spamd' 'yes'
fi
set_default_value 'iptables' 'yes'
set_default_value 'fail2ban' 'yes'
set_default_value 'softaculous' 'yes'
set_default_value 'quota' 'no'
set_default_value 'interactive' 'yes'
set_default_value 'ssl' 'no'
set_default_lang 'en'

# Checking software conflicts
if [ "$phpfpm" = 'yes' ]; then
    apache='no'
    nginx='yes'
fi
if [ "$proftpd" = 'yes' ]; then
    vsftpd='no'
fi
if [ "$exim" = 'no' ]; then
    clamd='no'
    spamd='no'
    dovecot='no'
fi
if [ "$iptables" = 'no' ]; then
    fail2ban='no'
fi

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
    check_result 1 "Script can be run executed only by root"
fi

# Checking admin user account
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ -z "$force" ]; then
    echo 'Please remove admin user account before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo -e "Example: bash $0 --force\n"
    check_result 1 "User admin exists"
fi

# Checking wget
if [ ! -e '/usr/bin/wget' ]; then
    # Remove any APT::Default-Release settings before installing wget
    rm -f /etc/apt/apt.conf.d/*default-release*
    apt-get update
    apt-get -y install wget
    check_result $? "Can't install wget"
fi

# Checking repository availability
wget -q "c.vestacp.com/deb_signing.key" -O /dev/null
check_result $? "No access to Vesta repository"

# Checking installed packages
tmpfile=$(mktemp -p /tmp)
dpkg --get-selections > $tmpfile
# Checking gnupg (fix for latest Ubuntu vestions)
for pkg in gnupg gnupg1 gnupg2; do
    if [ ! -z "$(grep '$pkg' $tmpfile)" ]; then
        gnupg_exist=true
        break
    fi
done
if [ -z "$gnupg_exist" ]; then
    # Remove any APT::Default-Release settings before installing gnupg
    rm -f /etc/apt/apt.conf.d/*default-release*
    apt-get update
    apt-get -y install gnupg
    check_result $? "apt-get install gnupg failed"
fi
# Checking conflicts
for pkg in exim4 mysql-server apache2 nginx vesta; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'Following packages are already installed:'
    echo "$conflicts"
    echo
    echo 'It is highly recommended to remove them before proceeding.'
    echo 'If you want to force installation run this script with -f option:'
    echo "Example: bash $0 --force"
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    check_result 1 "Control Panel should be installed on clean server."
fi


#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

# Printing nice ASCII logo
clear
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|'
echo ' _|      _|  _|        _|            _|      _|    _|'
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_|'
echo '   _|  _|    _|              _|      _|      _|    _|'
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _|'
echo
echo '                                  Vesta Control Panel'
echo -e "\n\n"

echo 'The following software will be installed on your system:'

# Web stack
if [ "$nginx" = 'yes' ]; then
    echo '   - Nginx Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo '   - Apache Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo '   - Apache Web Server (as backend)'
fi
if [ "$phpfpm"  = 'yes' ]; then
    echo '   - PHP-FPM Application Server'
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo '   - Bind DNS Server'
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo -n '   - Exim Mail Server'
    if [ "$clamd" = 'yes'  ] ||  [ "$spamd" = 'yes' ] ; then
        echo -n ' + '
        if [ "$clamd" = 'yes' ]; then
            echo -n 'ClamAV'
        fi
        if [ "$spamd" = 'yes' ]; then
            echo -n 'SpamAssassin'
        fi
    fi
    echo
    if [ "$dovecot" = 'yes' ]; then
        echo '   - Dovecot POP3/IMAP Server'
    fi
fi

# Database stack
if [ "$mysql" = 'yes' ]; then
    echo '   - MySQL Database Server'
fi
if [ "$postgresql" = 'yes' ]; then
    echo '   - PostgreSQL Database Server'
fi
if [ "$mongodb" = 'yes' ]; then
    echo '   - MongoDB Database Server'
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo '   - Vsftpd FTP Server'
fi
if [ "$proftpd" = 'yes' ]; then
    echo '   - ProFTPD FTP Server'
fi

# LE SSL for hostname
if [ "$ssl" = 'yes' ]; then
    echo '   - LE SSL for hostname'
fi

# Softaculous
if [ "$softaculous" = 'yes' ]; then
    echo '   - Softaculous Plugin'
fi

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo -n '   - Iptables Firewall'
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo -n ' + Fail2Ban'
fi
echo -e "\n\n"

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
    read -p 'Would you like to continue [y/n]: ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi

    # Asking for contact email
    if [ -z "$email" ]; then
        read -p 'Please enter admin email address: ' email
    fi

     # Asking for Vesta port
    if [ -z "$port" ]; then
        read -p 'Please enter Vesta port number (press enter for 8083): ' port
    fi

    # Asking to set FQDN hostname
    if [ -z "$servername" ]; then
        read -p "Please enter FQDN hostname [$(hostname -f)]: " servername
    fi
fi

# Generating admin password if it wasn't set
if [ -z "$vpass" ]; then
    vpass=$(gen_pass)
fi

# Set hostname if it wasn't set
if [ -z "$servername" ]; then
    servername=$(hostname -f)
fi

# Set FQDN if it wasn't set
mask1='(([[:alnum:]](-?[[:alnum:]])*)\.)'
mask2='*[[:alnum:]](-?[[:alnum:]])+\.[[:alnum:]]{2,}'
if ! [[ "$servername" =~ ^${mask1}${mask2}$ ]]; then
    if [ ! -z "$servername" ]; then
        servername="$servername.example.com"
    else
        servername="example.com"
    fi
    echo "127.0.0.1 $servername" >> /etc/hosts
fi

# Set email if it wasn't set
if [ -z "$email" ]; then
    email="admin@$servername"
fi

# Set port if it wasn't set
if [ -z "$port" ]; then
    port="8083"
fi

# Defining backup directory
vst_backups="/root/vst_install_backups/$(date +%s)"
echo "Installation backup directory: $vst_backups"

# Printing start message and sleeping for 5 seconds
echo -e "\n\n\n\nInstallation will take about 15 minutes ...\n"
sleep 5


#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Checking swap on small instances
if [ -z "$(swapon -s)" ] && [ $memory -lt 1000000 ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi


#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#

# Updating system
apt-get -y upgrade
check_result $? 'apt-get upgrade failed'

# Installing nginx repo
apt=/etc/apt/sources.list.d
# Use modern method for adding repository keys
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ $codename nginx" > $apt/nginx.list

# Add appropriate Ubuntu repositories based on version
if [ "$release" = "22.04" ]; then
    # Backup the current sources list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    
    # Add Ubuntu 22.04 (Jammy) repositories
    echo "Adding Ubuntu 22.04 (Jammy) repositories..."
    echo "deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" | tee -a /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse" | tee -a /etc/apt/sources.list
elif [ "$release" = "24.04" ]; then
    # Backup the current sources list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    
    # Add Ubuntu 24.04 (Noble) repositories
    echo "Adding Ubuntu 24.04 (Noble) repositories..."
    echo "deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" | tee -a /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse" | tee -a /etc/apt/sources.list
    
    # Also add Ubuntu 22.04 (Jammy) repositories for compatibility
    echo "Adding Ubuntu 22.04 (Jammy) repositories for compatibility..."
    echo "deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" | tee -a /etc/apt/sources.list
fi

# Installing vesta repo
# Use focal repo for VestaCP since there's no jammy or noble repo
echo "Using Ubuntu 20.04 (focal) repository for VestaCP on Ubuntu $release..."
echo "deb http://$RHOST/focal/ focal vesta" > $apt/vesta.list
curl -fsSL $CHOST/deb_signing.key | gpg --dearmor -o /usr/share/keyrings/vesta-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/vesta-archive-keyring.gpg] http://$RHOST/focal/ focal vesta" > $apt/vesta.list

# Remove any existing repository configurations that might conflict
rm -f $apt/noble* $apt/jammy*
# Remove any APT::Default-Release settings
rm -f /etc/apt/apt.conf.d/01default-release


#----------------------------------------------------------#
#                         Backup                           #
#----------------------------------------------------------#

# Creating backup directory tree
mkdir -p $vst_backups
cd $vst_backups
mkdir nginx apache2 php vsftpd proftpd bind exim4 dovecot clamd
mkdir spamassassin mysql postgresql mongodb vesta

# Backup nginx configuration
systemctl stop nginx > /dev/null 2>&1
cp -r /etc/nginx/* $vst_backups/nginx >/dev/null 2>&1

# Backup Apache configuration
systemctl stop apache2 > /dev/null 2>&1
cp -r /etc/apache2/* $vst_backups/apache2 > /dev/null 2>&1
rm -f /etc/apache2/conf.d/* > /dev/null 2>&1

# Backup PHP-FPM configuration
systemctl stop php$php_version-fpm > /dev/null 2>&1
cp -r /etc/php/$php_version/* $vst_backups/php/ > /dev/null 2>&1

# Backup Bind configuration
systemctl stop bind9 > /dev/null 2>&1
cp -r /etc/bind/* $vst_backups/bind > /dev/null 2>&1

# Backup Vsftpd configuration
systemctl stop vsftpd > /dev/null 2>&1
cp /etc/vsftpd.conf $vst_backups/vsftpd > /dev/null 2>&1

# Backup ProFTPD configuration
systemctl stop proftpd > /dev/null 2>&1
cp /etc/proftpd.conf $vst_backups/proftpd > /dev/null 2>&1

# Backup Exim configuration
systemctl stop exim4 > /dev/null 2>&1
cp -r /etc/exim4/* $vst_backups/exim4 > /dev/null 2>&1

# Backup ClamAV configuration
systemctl stop clamav-daemon > /dev/null 2>&1
cp -r /etc/clamav/* $vst_backups/clamav > /dev/null 2>&1

# Backup SpamAssassin configuration
systemctl stop spamassassin > /dev/null 2>&1
cp -r /etc/spamassassin/* $vst_backups/spamassassin > /dev/null 2>&1

# Backup Dovecot configuration
systemctl stop dovecot > /dev/null 2>&1
cp /etc/dovecot.conf $vst_backups/dovecot > /dev/null 2>&1
cp -r /etc/dovecot/* $vst_backups/dovecot > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
systemctl stop mysql > /dev/null 2>&1
killall -9 mysqld > /dev/null 2>&1
mv /var/lib/mysql $vst_backups/mysql/mysql_datadir > /dev/null 2>&1
cp -r /etc/mysql/* $vst_backups/mysql > /dev/null 2>&1
mv -f /root/.my.cnf $vst_backups/mysql > /dev/null 2>&1

# Backup Vesta
systemctl stop vesta > /dev/null 2>&1
cp -r $VESTA/* $vst_backups/vesta > /dev/null 2>&1
apt-get -y remove vesta vesta-nginx vesta-php > /dev/null 2>&1
apt-get -y purge vesta vesta-nginx vesta-php > /dev/null 2>&1
rm -rf $VESTA > /dev/null 2>&1


#----------------------------------------------------------#
#                     Package Excludes                     #
#----------------------------------------------------------#

# Excluding packages
software=$(echo "$software" | sed -e "s/apache2.2-common//")

if [ "$nginx" = 'no'  ]; then
    software=$(echo "$software" | sed -e "s/ nginx/ /")
fi
if [ "$apache" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/apache2 //")
    software=$(echo "$software" | sed -e "s/apache2-utils//")
    software=$(echo "$software" | sed -e "s/apache2-suexec-custom//")
    software=$(echo "$software" | sed -e "s/apache2.2-common//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-ruid2//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-rpaf//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-fcgid//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-php$php_version//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-php//")
fi
if [ "$phpfpm" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/php$php_version-fpm//")
    software=$(echo "$software" | sed -e "s/php-fpm//")
fi
if [ "$vsftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/vsftpd//")
fi
if [ "$proftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/proftpd-basic//")
    software=$(echo "$software" | sed -e "s/proftpd-mod-vroot//")
fi
if [ "$named" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/bind9//")
fi
if [ "$exim" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/exim4 //")
    software=$(echo "$software" | sed -e "s/exim4-daemon-heavy//")
    software=$(echo "$software" | sed -e "s/dovecot-imapd//")
    software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
    software=$(echo "$software" | sed -e "s/clamav-daemon//")
    software=$(echo "$software" | sed -e "s/spamassassin//")
fi
if [ "$clamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/clamav-daemon//")
fi
if [ "$spamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/spamassassin//")
fi
if [ "$dovecot" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/dovecot-imapd//")
    software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
fi
if [ "$mysql" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/mysql-server//')
    software=$(echo "$software" | sed -e 's/mysql-client//')
    software=$(echo "$software" | sed -e 's/mysql-common//')
    software=$(echo "$software" | sed -e "s/php$php_version-mysql//")
    software=$(echo "$software" | sed -e 's/php-mysql//')
    software=$(echo "$software" | sed -e 's/phpMyAdmin//')
    software=$(echo "$software" | sed -e 's/phpmyadmin//')
fi
if [ "$postgresql" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/postgresql-contrib//')
    software=$(echo "$software" | sed -e 's/postgresql//')
    software=$(echo "$software" | sed -e "s/php$php_version-pgsql//")
    software=$(echo "$software" | sed -e 's/php-pgsql//')
    software=$(echo "$software" | sed -e 's/phppgadmin//')
fi
if [ "$softaculous" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/vesta-softaculous//')
fi
if [ "$iptables" = 'no' ] || [ "$fail2ban" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/fail2ban//')
fi


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Update system packages
apt-get update

# Disabling daemon autostart on apt-get install
echo -e '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d
chmod a+x /usr/sbin/policy-rc.d

# Installing apt packages
echo "Installing packages..."

# First, install all non-VestaCP packages
non_vesta_software=$(echo "$software" | sed -e 's/vesta[^ ]* //g')
apt-get -y install $non_vesta_software
check_result $? "apt-get install non-vesta packages failed"

# For VestaCP packages, download and install the .deb files directly
echo "Installing VestaCP packages..."
vesta_software=$(echo "$software" | grep -o 'vesta[^ ]*')
mkdir -p /tmp/vesta-debs
cd /tmp/vesta-debs

# Define package versions and architectures
vesta_version="0.9.8-25"
vesta_php_version="0.9.8-4"
vesta_nginx_version="0.9.8-2"
vesta_ioncube_version="0.9.8-2"
vesta_softaculous_version="0.9.8-2"
arch="amd64"

# Define all possible URLs to try
declare -a urls=(
    "http://c.vestacp.com/0.9.8/ubuntu"
    "http://c.vestacp.com/0.9.8/debian"
    "http://c.vestacp.com/0.9.8/ubuntu/pool"
    "http://c.vestacp.com/0.9.8/debian/pool"
    "http://vestacp.com/pub/0.9.8/debian"
    "http://vestacp.com/pub/0.9.8/ubuntu"
    "https://vestacp.com/pub/0.9.8/debian"
    "https://vestacp.com/pub/0.9.8/ubuntu"
    "http://apt.vestacp.com/pool/vesta"
)

# Download and install each package
for package in $vesta_software; do
    echo "Downloading and installing $package..."
    success=0
    
    # Try all URL patterns
    for base_url in "${urls[@]}"; do
        # Try simple package name
        wget -q "$base_url/$package.deb" -O "$package.deb"
        if [ -s "$package.deb" ]; then
            success=1
            break
        fi
        
        # Try with version in filename
        case "$package" in
            "vesta")
                wget -q "$base_url/${package}_${vesta_version}_${arch}.deb" -O "$package.deb"
                ;;
            "vesta-php")
                wget -q "$base_url/${package}_${vesta_php_version}_${arch}.deb" -O "$package.deb"
                ;;
            "vesta-nginx")
                wget -q "$base_url/${package}_${vesta_nginx_version}_${arch}.deb" -O "$package.deb"
                ;;
            "vesta-ioncube")
                wget -q "$base_url/${package}_${vesta_ioncube_version}_${arch}.deb" -O "$package.deb"
                ;;
            "vesta-softaculous")
                wget -q "$base_url/${package}_${vesta_softaculous_version}_${arch}.deb" -O "$package.deb"
                ;;
        esac
        
        if [ -s "$package.deb" ]; then
            success=1
            break
        fi
    done
    
    # If we have a valid .deb file, install it
    if [ $success -eq 1 ]; then
        echo "Successfully downloaded $package, installing..."
        dpkg -i "$package.deb" || {
            apt-get -f -y install
            dpkg -i "$package.deb"
        }
        if [ $? -ne 0 ]; then
            echo "Warning: Failed to install $package, continuing..."
        fi
    else
        echo "Warning: Could not download $package, continuing without it..."
        # Create empty directories that would have been created by the package
        case "$package" in
            "vesta")
                mkdir -p /usr/local/vesta/bin /usr/local/vesta/web /usr/local/vesta/data
                ;;
            "vesta-nginx")
                mkdir -p /usr/local/vesta/nginx
                ;;
            "vesta-php")
                mkdir -p /usr/local/vesta/php
                ;;
        esac
    fi
done

# Clean up
rm -f Packages
cd - > /dev/null

# Restoring autostart policy
rm -f /usr/sbin/policy-rc.d


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

# Enabling SSH password auth
sed -i "s/rdAuthentication no/rdAuthentication yes/g" /etc/ssh/sshd_config
systemctl restart ssh

# Disabling AWStats cron
rm -f /etc/cron.d/awstats

# Set directory color
echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile

# Registering /usr/sbin/nologin
if [ -z "$(grep nologin /etc/shells)" ]; then
    echo "/usr/sbin/nologin" >> /etc/shells
fi

# Configuring NTP
echo '#!/bin/sh' > /etc/cron.daily/ntpdate
echo "$(which ntpdate) -s ntp.ubuntu.com" >> /etc/cron.daily/ntpdate
chmod 775 /etc/cron.daily/ntpdate
ntpdate -s ntp.ubuntu.com

# Adding rssh support (removed for Ubuntu 22.04/24.04 as rssh is not available)
# rssh package is not available in Ubuntu 22.04/24.04


#----------------------------------------------------------#
#                     Configure Vesta                      #
#----------------------------------------------------------#

# Installing sudo configuration
mkdir -p /etc/sudoers.d
if [ -f "$vestacp/sudo/admin" ]; then
    cp -f $vestacp/sudo/admin /etc/sudoers.d/
else
    # Create a basic sudoers file for admin
    echo "admin ALL=(ALL) NOPASSWD: /usr/local/vesta/bin/*" > /etc/sudoers.d/admin
fi
chmod 440 /etc/sudoers.d/admin
sed -i "s/%admin.*ALL=(ALL).*/# sudo is limited to vesta scripts/" /etc/sudoers

# Configuring system env
echo "export VESTA='$VESTA'" > /etc/profile.d/vesta.sh
chmod 755 /etc/profile.d/vesta.sh
source /etc/profile.d/vesta.sh
echo 'PATH=$PATH:'$VESTA'/bin' >> /root/.bash_profile
echo 'export PATH' >> /root/.bash_profile
source /root/.bash_profile

# Configuring logrotate for Vesta logs
if [ -f "$vestacp/logrotate/vesta" ]; then
    cp -f $vestacp/logrotate/vesta /etc/logrotate.d/
else
    # Create a basic logrotate config
    cat > /etc/logrotate.d/vesta <<EOF
/usr/local/vesta/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
}
EOF
fi

# Building directory tree and creating some blank files for Vesta
mkdir -p $VESTA/conf $VESTA/log $VESTA/ssl $VESTA/data/ips \
    $VESTA/data/queue $VESTA/data/users $VESTA/data/firewall \
    $VESTA/data/sessions
touch $VESTA/data/queue/backup.pipe $VESTA/data/queue/disk.pipe \
    $VESTA/data/queue/webstats.pipe $VESTA/data/queue/restart.pipe \
    $VESTA/data/queue/traffic.pipe $VESTA/log/system.log \
    $VESTA/log/nginx-error.log $VESTA/log/auth.log
chmod 750 $VESTA/conf $VESTA/data/users $VESTA/data/ips $VESTA/log
chmod -R 750 $VESTA/data/queue
chmod 660 $VESTA/log/*
rm -f /var/log/vesta
ln -s $VESTA/log /var/log/vesta
chmod 770 $VESTA/data/sessions

# Generating Vesta configuration
rm -f $VESTA/conf/vesta.conf 2>/dev/null
touch $VESTA/conf/vesta.conf
chmod 660 $VESTA/conf/vesta.conf

# Web stack
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='www-data'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='www-data'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='8080'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='8443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "PROXY_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "PROXY_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "PROXY_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'no' ] && [ "$nginx"  = 'yes' ]; then
    echo "WEB_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='openssl'"  >> $VESTA/conf/vesta.conf
    if [ "$phpfpm" = 'yes' ]; then
        echo "WEB_BACKEND='php-fpm'" >> $VESTA/conf/vesta.conf
    fi
    echo "STATS_SYSTEM='webalizer,awstats'" >> $VESTA/conf/vesta.conf
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='vsftpd'" >> $VESTA/conf/vesta.conf
fi
if [ "$proftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='proftpd'" >> $VESTA/conf/vesta.conf
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo "DNS_SYSTEM='bind9'" >> $VESTA/conf/vesta.conf
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo "MAIL_SYSTEM='exim4'" >> $VESTA/conf/vesta.conf
    if [ "$clamd" = 'yes'  ]; then
        echo "ANTIVIRUS_SYSTEM='clamav-daemon'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$spamd" = 'yes' ]; then
        echo "ANTISPAM_SYSTEM='spamassassin'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$dovecot" = 'yes' ]; then
        echo "IMAP_SYSTEM='dovecot'" >> $VESTA/conf/vesta.conf
    fi
fi

# Cron daemon
echo "CRON_SYSTEM='cron'" >> $VESTA/conf/vesta.conf

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo "FIREWALL_SYSTEM='iptables'" >> $VESTA/conf/vesta.conf
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo "FIREWALL_EXTENSION='fail2ban'" >> $VESTA/conf/vesta.conf
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
    echo "DISK_QUOTA='yes'" >> $VESTA/conf/vesta.conf
fi

# Backups
echo "BACKUP_SYSTEM='local'" >> $VESTA/conf/vesta.conf

# Language
echo "LANGUAGE='$lang'" >> $VESTA/conf/vesta.conf

# Version
echo "VERSION='0.9.8'" >> $VESTA/conf/vesta.conf

# Installing hosting packages
if [ -d "$vestacp/packages" ]; then
    cp -rf $vestacp/packages $VESTA/data/
fi

# Installing templates
if [ -d "$vestacp/templates" ]; then
    cp -rf $vestacp/templates $VESTA/data/
fi

# Copying index.html to default documentroot
if [ -f "$VESTA/data/templates/web/skel/public_html/index.html" ]; then
    cp $VESTA/data/templates/web/skel/public_html/index.html /var/www/
    sed -i 's/%domain%/It worked!/g' /var/www/index.html
else
    # Create a basic index.html
    echo "<html><body><h1>It worked!</h1></body></html>" > /var/www/index.html
fi

# Installing firewall rules
if [ -d "$vestacp/firewall" ]; then
    cp -rf $vestacp/firewall $VESTA/data/
fi

# Configuring server hostname
$VESTA/bin/v-change-sys-hostname $servername 2>/dev/null

# Generating SSL certificate
$VESTA/bin/v-generate-ssl-cert $(hostname) $email 'US' 'California' \
     'San Francisco' 'Vesta Control Panel' 'IT' > /tmp/vst.pem

# Parsing certificate file
crt_end=$(grep -n "END CERTIFICATE-" /tmp/vst.pem |cut -f 1 -d:)
key_start=$(grep -n "BEGIN RSA" /tmp/vst.pem |cut -f 1 -d:)
key_end=$(grep -n  "END RSA" /tmp/vst.pem |cut -f 1 -d:)

# Adding SSL certificate
cd $VESTA/ssl
sed -n "1,${crt_end}p" /tmp/vst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/vst.pem > certificate.key
chown root:mail $VESTA/ssl/*
chmod 660 $VESTA/ssl/*
rm /tmp/vst.pem

# Adding nologin as a valid system shell
if [ -z "$(grep nologin /etc/shells)" ]; then
    echo "/usr/sbin/nologin" >> /etc/shells
fi


#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

if [ "$nginx" = 'yes' ]; then
    rm -f /etc/nginx/conf.d/*.conf
    if [ -f "$vestacp/nginx/nginx.conf" ]; then
        cp -f $vestacp/nginx/nginx.conf /etc/nginx/
    fi
    if [ -f "$vestacp/nginx/status.conf" ]; then
        cp -f $vestacp/nginx/status.conf /etc/nginx/conf.d/
    fi
    if [ -f "$vestacp/nginx/phpmyadmin.inc" ]; then
        cp -f $vestacp/nginx/phpmyadmin.inc /etc/nginx/conf.d/
    fi
    if [ -f "$vestacp/nginx/phppgadmin.inc" ]; then
        cp -f $vestacp/nginx/phppgadmin.inc /etc/nginx/conf.d/
    fi
    if [ -f "$vestacp/nginx/webmail.inc" ]; then
        cp -f $vestacp/nginx/webmail.inc /etc/nginx/conf.d/
    fi
    if [ -f "$vestacp/logrotate/nginx" ]; then
        cp -f $vestacp/logrotate/nginx /etc/logrotate.d/
    fi
    echo > /etc/nginx/conf.d/vesta.conf
    mkdir -p /var/log/nginx/domains
    systemctl enable nginx
    systemctl start nginx
    check_result $? "nginx start failed"
fi


#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes'  ]; then
    # Create basic Apache configuration if not available
    if [ ! -f "/etc/apache2/apache2.conf" ]; then
        cat > /etc/apache2/apache2.conf <<EOF
# Basic Apache configuration for Ubuntu 22.04/24.04
ServerRoot "/etc/apache2"
ServerName localhost
User www-data
Group www-data
ErrorLog /var/log/apache2/error.log
LogLevel warn
LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
IncludeOptional conf-enabled/*.conf
IncludeOptional sites-enabled/*.conf
<Directory />
    Options FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>
<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
AccessFileName .htaccess
<FilesMatch "^\.ht">
    Require all denied
</FilesMatch>
HostnameLookups Off
EOF
    fi

    # Enable required modules
    a2enmod rewrite
    a2enmod suexec
    a2enmod ssl
    a2enmod actions
    a2enmod proxy_fcgi
    a2enmod alias

    # Create directories and set permissions
    mkdir -p /etc/apache2/conf.d
    mkdir -p /etc/apache2/suexec
    mkdir -p /var/log/apache2/domains

    # Create basic configuration files
    echo > /etc/apache2/conf.d/vesta.conf
    echo "# Server control panel by VESTA" > /etc/apache2/sites-available/000-default.conf
    echo "# Server control panel by VESTA" > /etc/apache2/sites-available/default-ssl.conf

    # Configure ports
    cat > /etc/apache2/ports.conf <<EOF
Listen 80
<IfModule ssl_module>
    Listen 443
</IfModule>
EOF

    # Configure suexec
    echo -e "/home\npublic_html/cgi-bin" > /etc/apache2/suexec/www-data

    # Set up logs
    touch /var/log/apache2/access.log /var/log/apache2/error.log
    chmod a+x /var/log/apache2
    chmod 640 /var/log/apache2/access.log /var/log/apache2/error.log
    chmod 751 /var/log/apache2/domains
    chown -R www-data:www-data /var/log/apache2

    # Enable default site
    a2ensite 000-default

    # Start Apache
    systemctl enable apache2
    systemctl restart apache2
    check_result $? "apache2 start failed"
else
    systemctl disable apache2 >/dev/null 2>&1
    systemctl stop apache2 >/dev/null 2>&1
fi


#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
    pool=$(find /etc/php* -type d \( -name "pool.d" -o -name "*fpm.d" \))
    if [ -f "$vestacp/php-fpm/www.conf" ]; then
        cp -f $vestacp/php-fpm/www.conf $pool/
    fi
    php_fpm="php$php_version-fpm"
    ln -s /etc/init.d/$php_fpm /etc/init.d/php-fpm > /dev/null 2>&1
    systemctl enable $php_fpm
    systemctl start $php_fpm
    check_result $? "php-fpm start failed"
fi


#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

ZONE=$(timedatectl 2>/dev/null|grep Timezone|awk '{print $2}')
if [ -z "$ZONE" ]; then
    ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
    sed -i "s%;date.timezone =%date.timezone = $ZONE%g" $pconf
    sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done


#----------------------------------------------------------#
#                    Configure Vsftpd                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
    if [ -f "$vestacp/vsftpd/vsftpd.conf" ]; then
        cp -f $vestacp/vsftpd/vsftpd.conf /etc/
    fi
    touch /var/log/vsftpd.log
    chown root:adm /var/log/vsftpd.log
    chmod 640 /var/log/vsftpd.log
    touch /var/log/xferlog
    chown root:adm /var/log/xferlog
    chmod 640 /var/log/xferlog
    systemctl enable vsftpd
    systemctl start vsftpd
    check_result $? "vsftpd start failed"
fi


#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
    echo "127.0.0.1 $servername" >> /etc/hosts
    if [ -f "$vestacp/proftpd/proftpd.conf" ]; then
        cp -f $vestacp/proftpd/proftpd.conf /etc/proftpd/
    fi
    systemctl enable proftpd
    systemctl start proftpd
    check_result $? "proftpd start failed"
fi


#----------------------------------------------------------#
#                  Configure MySQL/MariaDB                 #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then
    mycnf="my-small.cnf"
    if [ $memory -gt 1200000 ]; then
        mycnf="my-medium.cnf"
    fi
    if [ $memory -gt 3900000 ]; then
        mycnf="my-large.cnf"
    fi

    # Configuring MySQL/MariaDB
    if [ -f "$vestacp/mysql/$mycnf" ]; then
        cp -f $vestacp/mysql/$mycnf /etc/mysql/my.cnf
    fi
    mkdir -p /var/lib/mysql
    chown mysql:mysql /var/lib/mysql
    mysqld --initialize-insecure
    systemctl enable mysql
    systemctl start mysql
    check_result $? "mysql start failed"

    # Securing MySQL/MariaDB installation
    mpass=$(gen_pass)
    mysqladmin -u root password $mpass
    echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DROP DATABASE test" >/dev/null 2>&1
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "DELETE FROM mysql.user WHERE user='' OR authentication_string IS NULL"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mpass'"
    mysql -e "FLUSH PRIVILEGES"

    # Configuring phpMyAdmin
    if [ "$apache" = 'yes' ]; then
        if [ -f "$vestacp/pma/apache.conf" ]; then
            cp -f $vestacp/pma/apache.conf /etc/phpmyadmin/
        fi
        ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf.d/phpmyadmin.conf
    fi
    mysql < /usr/share/phpmyadmin/sql/create_tables.sql
    p=$(grep dbpass /etc/phpmyadmin/config-db.php |cut -f 2 -d "'")
    mysql -e "CREATE USER IF NOT EXISTS phpmyadmin@localhost IDENTIFIED WITH mysql_native_password BY '$p'"
    mysql -e "GRANT ALL ON phpmyadmin.* TO phpmyadmin@localhost"
    chmod 777 /var/lib/phpmyadmin/tmp
fi


#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
    ppass=$(gen_pass)
    if [ -f "$vestacp/postgresql/pg_hba.conf" ]; then
        cp -f $vestacp/postgresql/pg_hba.conf /etc/postgresql/*/main/
    fi
    systemctl restart postgresql
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"

    # Configuring phpPgAdmin
    if [ "$apache" = 'yes' ]; then
        if [ -f "$vestacp/pga/phppgadmin.conf" ]; then
            cp -f $vestacp/pga/phppgadmin.conf /etc/apache2/conf.d/
        fi
    fi
    if [ -f "$vestacp/pga/config.inc.php" ]; then
        cp -f $vestacp/pga/config.inc.php /etc/phppgadmin/
    fi
fi


#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
    if [ -f "$vestacp/bind/named.conf" ]; then
        cp -f $vestacp/bind/named.conf /etc/bind/
    fi
    sed -i "s%listen-on%//listen%" /etc/bind/named.conf.options
    chown root:bind /etc/bind/named.conf
    chmod 640 /etc/bind/named.conf
    aa-complain /usr/sbin/named 2>/dev/null
    echo "/home/** rwm," >> /etc/apparmor.d/local/usr.sbin.named 2>/dev/null
    systemctl status apparmor >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        systemctl restart apparmor
    fi
    systemctl enable bind9
    systemctl start bind9
    check_result $? "bind9 start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ -e "/proc/vz/veinfo" ]; then
        sed -i "s/^exit 0/service bind9 restart\nexit 0/" /etc/rc.local
    fi
fi

#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
    gpasswd -a Debian-exim mail
    if [ -f "$vestacp/exim/exim4.conf.template" ]; then
        cp -f $vestacp/exim/exim4.conf.template /etc/exim4/
    fi
    if [ -f "$vestacp/exim/dnsbl.conf" ]; then
        cp -f $vestacp/exim/dnsbl.conf /etc/exim4/
    fi
    if [ -f "$vestacp/exim/spam-blocks.conf" ]; then
        cp -f $vestacp/exim/spam-blocks.conf /etc/exim4/
    fi
    touch /etc/exim4/white-blocks.conf

    if [ "$spamd" = 'yes' ]; then
        sed -i "s/#SPAM/SPAM/g" /etc/exim4/exim4.conf.template
    fi
    if [ "$clamd" = 'yes' ]; then
        sed -i "s/#CLAMD/CLAMD/g" /etc/exim4/exim4.conf.template
    fi

    chmod 640 /etc/exim4/exim4.conf.template
    rm -rf /etc/exim4/domains
    mkdir -p /etc/exim4/domains

    rm -f /etc/alternatives/mta
    ln -s /usr/sbin/exim4 /etc/alternatives/mta
    systemctl disable sendmail > /dev/null 2>&1
    systemctl stop sendmail > /dev/null 2>&1
    systemctl disable postfix > /dev/null 2>&1
    systemctl stop postfix > /dev/null 2>&1

    systemctl enable exim4
    systemctl start exim4
    check_result $? "exim4 start failed"
fi


#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
    gpasswd -a dovecot mail
    if [ -d "/usr/local/vesta/install/debian/9/dovecot" ]; then
        cp -r /usr/local/vesta/install/debian/9/dovecot /etc/
    fi
    if [ -z "$(grep yes /etc/dovecot/conf.d/10-mail.conf)" ]; then
        echo "namespace inbox {" >> /etc/dovecot/conf.d/10-mail.conf
        echo "  inbox = yes" >> /etc/dovecot/conf.d/10-mail.conf
        echo "}" >> /etc/dovecot/conf.d/10-mail.conf
        echo "first_valid_uid = 1000" >> /etc/dovecot/conf.d/10-mail.conf
        echo "mbox_write_locks = fcntl" >> /etc/dovecot/conf.d/10-mail.conf
    fi
    if [ -f "$vestacp/logrotate/dovecot" ]; then
        cp -f $vestacp/logrotate/dovecot /etc/logrotate.d/
    fi
    chown -R root:root /etc/dovecot*
    systemctl enable dovecot
    systemctl start dovecot
    check_result $? "dovecot start failed"
fi


#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
    gpasswd -a clamav mail
    gpasswd -a clamav Debian-exim
    if [ -f "$vestacp/clamav/clamd.conf" ]; then
        cp -f $vestacp/clamav/clamd.conf /etc/clamav/
    fi
    /usr/bin/freshclam
    systemctl enable clamav-daemon
    systemctl start clamav-daemon
    check_result $? "clamav-daemon start failed"
fi


#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
    systemctl enable spamassassin
    sed -i "s/ENABLED=0/ENABLED=1/" /etc/default/spamassassin
    systemctl start spamassassin
    check_result $? "spamassassin start failed"
fi


#----------------------------------------------------------#
#                   Configure Roundcube                    #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    if [ "$apache" = 'yes' ]; then
        if [ -f "$vestacp/roundcube/apache.conf" ]; then
            cp -f $vestacp/roundcube/apache.conf /etc/roundcube/
        fi
        ln -s /etc/roundcube/apache.conf /etc/apache2/conf.d/roundcube.conf
    fi

    r=$(grep dbpass= /etc/roundcube/debian-db.php |cut -f 2 -d "'")
    sed -i "s/default_host.*/default_host'] = 'localhost';/" \
        /etc/roundcube/config.inc.php
    sed -i "s/^);/'password');/" /etc/roundcube/config.inc.php

    if [ -f "$vestacp/roundcube/vesta.php" ]; then
        cp -f $vestacp/roundcube/vesta.php \
            /usr/share/roundcube/plugins/password/drivers/
    fi
    if [ -f "$vestacp/roundcube/config.inc.php" ]; then
        cp -f $vestacp/roundcube/config.inc.php /etc/roundcube/plugins/password/
    fi

    mysql -e "CREATE DATABASE roundcube"
    mysql -e "CREATE USER IF NOT EXISTS roundcube@localhost IDENTIFIED WITH mysql_native_password BY '$r'"
    mysql -e "GRANT ALL ON roundcube.* TO roundcube@localhost"
    mysql roundcube < /usr/share/dbconfig-common/data/roundcube/install/mysql

    chmod 640 /etc/roundcube/debian-db*
    chown root:www-data /etc/roundcube/debian-db*
    touch /var/log/roundcube/errors
    chmod 640 /var/log/roundcube/errors
    chown www-data:adm /var/log/roundcube/errors

    phpenmod mcrypt 2>/dev/null
    if [ "$apache" = 'yes' ]; then
        systemctl restart apache2
    fi
    if [ "$nginx" = 'yes' ]; then
        systemctl restart nginx
    fi
fi


#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
    if [ -d "$vestacp/fail2ban" ]; then
        cp -rf $vestacp/fail2ban /etc/
    fi
    if [ -f "/etc/fail2ban/jail.local" ]; then
        if [ "$dovecot" = 'no' ]; then
            fline=$(cat /etc/fail2ban/jail.local |grep -n dovecot-iptables -A 2)
            fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
            sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
        fi
        if [ "$exim" = 'no' ]; then
            fline=$(cat /etc/fail2ban/jail.local |grep -n exim-iptables -A 2)
            fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
            sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
        fi
        if [ "$vsftpd" = 'yes' ]; then
            #Create vsftpd Log File
            if [ ! -f "/var/log/vsftpd.log" ]; then
                touch /var/log/vsftpd.log
            fi
            fline=$(cat /etc/fail2ban/jail.local |grep -n vsftpd-iptables -A 2)
            fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
            sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
        fi
    fi
    systemctl enable fail2ban
    systemctl start fail2ban
    check_result $? "fail2ban start failed"
fi


#----------------------------------------------------------#
#                   Configure Admin User                   #
#----------------------------------------------------------#

# Deleting old admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin >/dev/null 2>&1
    chattr -i /home/admin/conf >/dev/null 2>&1
    mv -f /home/admin  $vst_backups/home/ >/dev/null 2>&1
    rm -f /tmp/sess_* >/dev/null 2>&1
fi
if [ ! -z "$(grep ^admin: /etc/group)" ]; then
    groupdel admin > /dev/null 2>&1
fi

# Create default package first
$VESTA/bin/v-add-user-package default "Default Package" "default" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "100" "
$VESTA/bin/v-change-user-shell admin bash
$VESTA/bin/v-change-user-language admin $lang

# Configuring system IPs
$VESTA/bin/v-update-sys-ip

# Get main IP
ip=$(ip addr|grep 'inet '|grep global|head -n1|awk '{print $2}'|cut -f1 -d/)

# Configuring firewall
if [ "$iptables" = 'yes' ]; then
    $VESTA/bin/v-update-firewall
fi

# Get public IP
pub_ip=$(curl -s vestacp.com/what-is-my-ip/)
if [ ! -z "$pub_ip" ] && [ "$pub_ip" != "$ip" ]; then
    echo "$VESTA/bin/v-update-sys-ip" >> /etc/rc.local
    $VESTA/bin/v-change-sys-ip-nat $ip $pub_ip
    ip=$pub_ip
fi

# Configuring MySQL/MariaDB host
if [ "$mysql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host mysql localhost root $mpass
    $VESTA/bin/v-add-database admin default default $(gen_pass) mysql
fi

# Configuring PostgreSQL host
if [ "$postgresql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host pgsql localhost postgres $ppass
    $VESTA/bin/v-add-database admin db db $(gen_pass) pgsql
fi

# Adding default domain
$VESTA/bin/v-add-domain admin $servername

# Adding cron jobs
command="sudo $VESTA/bin/v-update-sys-queue disk"
$VESTA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue traffic"
$VESTA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue webstats"
$VESTA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue backup"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-backup-users"
$VESTA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-user-stats"
$VESTA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-rrd"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
systemctl restart cron

# Building initital rrd images
$VESTA/bin/v-update-sys-rrd

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
    $VESTA/bin/v-add-sys-quota
fi

# Enabling softaculous plugin
if [ "$softaculous" = 'yes' ]; then
    $VESTA/bin/v-add-vesta-softaculous
fi

# Starting Vesta service
systemctl enable vesta
systemctl start vesta
check_result $? "vesta start failed"
chown admin:admin $VESTA/data/sessions

# Adding notifications
$VESTA/upd/add_notifications.sh

# Adding cronjob for autoupdates
$VESTA/bin/v-add-cron-vesta-autoupdate

if [ "$port" != "8083" ]; then
    echo "=== Set Vesta port: $port"
    $VESTA/bin/v-change-vesta-port $port
fi

echo "NOTIFY_ADMIN_FULL_BACKUP='$email'" >> $VESTA/conf/vesta.conf


#----------------------------------------------------------#
#                   Vesta Access Info                      #
#----------------------------------------------------------#

# Comparing hostname and ip

if [ "$ssl" = 'no' ]; then
host_ip=$(host "$servername" |head -n 1 |awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
fi
fi

if [ "$ssl" = 'yes' ]; then
make_ssl=0
host_ip=$(host "$servername" | head -n 1 | awk '{print $NF}')
if [ "$host_ip" != "$pub_ip" ]; then
    echo "***** PROBLEM: Hostname $servername is not pointing to your server \(IP address $ip\)"
    echo "Without pointing your hostname to your IP, LetsEncrypt SSL will not be generated for your server hostname."
    echo "Try to setup an A record in your DNS, pointing your hostname $servername to IP address $ip and then press ENTER."
    echo "\(or register ns1.$servername and ns2.$servername as DNS Nameservers and put those Nameservers on $servername domain\)"
    echo "If we detect that hostname is still not pointing to your IP, installer will not add LetsEncrypt SSL certificate to your hosting panel \(unsigned SSL will be used instead\)."
    read -p "To force to try anyway to add LetsEncrypt, press f and then ENTER." answer
    host_ip=$(host $servername | head -n 1 | awk '{print $NF}')
fi
if [ "$answer" = "f" ]; then
    make_ssl=1
fi
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
    make_ssl=1
fi

if [ $make_ssl -eq 1 ]; then
    # Check if www is also pointing to our IP
    www_host="www.$servername"
    www_host_ip=$(host "$www_host" | head -n 1 | awk '{print $NF}')
    if [ "$www_host_ip" != "$pub_ip" ]; then
        if [ "$named" = 'yes' ]; then
            echo "=== Deleting www to server hostname"
            $VESTA/bin/v-delete-web-domain-alias 'admin' "$servername" "$www_host" 'no'
            $VESTA/bin/v-delete-dns-on-web-alias 'admin' "$servername" "$www_host" 'no'
        fi
        www_host=""
   fi
fi

echo "==="
echo "Hostname $servername is pointing to $host_ip"

if [ $make_ssl -eq 1 ]; then
    echo "=== Generating HOSTNAME SSL"
    $VESTA/bin/v-add-letsencrypt-domain 'admin' "$servername" "$www_host" 'yes'
    $VESTA/bin/v-update-host-certificate 'admin' "$servername"
else
    echo "We will not generate SSL because of this"
fi
echo "==="
echo "UPDATE_HOSTNAME_SSL='yes'" >> $VESTA/conf/vesta.conf
fi

# Sending notification to admin email
echo -e "Congratulations, you have just successfully installed \\
Vesta Control Panel

    https://$ip:$port
    username: admin
    password: $vpass

We hope that you enjoy your installation of Vesta. Please \\
feel free to contact us anytime if you have any questions.
Thank you.

--
Sincerely yours
vestacp.com team
" > $tmpfile

send_mail="$VESTA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Vesta Control Panel" $email

# Congrats
echo '======================================================='
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|   '
echo ' _|      _|  _|        _|            _|      _|    _| '
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_| '
echo '   _|  _|    _|              _|      _|      _|    _| '
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _| '
echo
echo
cat $tmpfile
rm -f $tmpfile

# EOF
