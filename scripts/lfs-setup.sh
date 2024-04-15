#! /bin/bash

clear
echo "Cricket's LFS setup script v0.1"
echo "WARNING: refer to: PLACEHOLDER_URL for instructions."

# Get drive info and partiton data from user.

echo -n "Root partition: "
read ROOT_PART
if ! [ -b /dev/"$ROOT_PART" ]; then
	echo "ERROR: block device does not exist!"
	exit -1
fi

echo -n "EFI system partition: "
read EFI_PART
if ! [ -b /dev/"$EFI_PART" ]; then
	echo "ERROR: block device does not exist!"
	exit -1
fi

echo -n "Home partition: "
read HOME_PART
if ! [ -b /dev/"$HOME_PART" ]; then
	echo "ERROR: block device does not exist!"
	exit -1
fi

echo -n "Opt partition: "
read OPT_PART
if ! [ -b /dev/"$OPT_PART" ]; then
	echo "ERROR: block device does not exist!"
	exit -1
fi

echo -n "Swap partition: "
read SWAP_PART
if ! [ -b /dev/"$SWAP_PART" ]; then
	echo "ERROR: block device does not exist!"
	exit -1
fi

# Check if lfs user exists, if not, create the lfs user.

if ! id lfs >/dev/null 2>&1; then
    	echo "Creating lfs user now."
	sudo groupadd lfs
    	sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
	sudo passwd lfs
	sudo chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
	sudo chown -v lfs $LFS/lib64
	echo "Please add lfs to the /etc/sudoers file, then rerun this script as lfs."
else
	echo "WARNING: lfs user already present."
fi

if ! [[ $(whoami) == "lfs" ]]; then
	echo "ERROR: please run this script as the lfs user!"
	exit
fi

# Make file structure, then mount partitions.

LFS=/mnt/lfs
sudo mkdir -pv $LFS
sudo mount /dev/"$ROOT_PART" $LFS
echo "Mounted "$ROOT_PART" to "$LFS
sudo mkdir -v $LFS/home
sudo mount /dev/"$HOME_PART" $LFS/home
echo "Mounted "$HOME_PART" to "$LFS"/home"
sudo mkdir -pv $LFS/boot/efi
sudo mount /dev/"$EFI_PART" $LFS/boot/efi
echo "Mounted "$HOME_PART" to "$LFS"/boot/efi"
sudo mkdir -v $LFS/opt
sudo mount /dev/"$OPT_PART" $LFS/opt
echo "Mounted "$OPT_PART" to "$LFS"/opt"
sudo mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
sudo mkdir -v $LFS/{tools,src}

for i in bin lib sbin; do
  sudo ln -sv usr/$i $LFS/$i
done

set +o posix

case $(uname -m) in
  x86_64) sudo mkdir -pv $LFS/lib64 ;;
esac



# Make sure the LFS directories are owned by the lfs user.

sudo chown -v lfs $LFS/{usr{,/*},lib,boot,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) sudo chown -v lfs $LFS/lib64 ;;
esac

sudo chmod -v a+wt $LFS/src
sudo chown -v lfs $LFS/src

# Env. setup

echo -n "Seting up lfs user env"
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
echo -n "."

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
echo -n "."

sudo [ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
echo -n "."

cat >> ~/.bashrc << "EOF"
export MAKEFLAGS=-j$(nproc)
EOF
echo " DONE"

echo "Reloading shell, please run lfs-toolchain.sh to continue the build."
source ~/.bash_profile
exit # this should never be reached
