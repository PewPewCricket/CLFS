#! /bin/bash

clear
echo "Cricket's LFS toolchain builder script v0.1"
echo "WARNING: refer to PLACEHLDER_URL for instructions."

# check env.

if ! [[ $(whoami) == "lfs" ]]; then
	echo "ERROR: please run this script as the lfs user!"
	exit
fi

if ! [[ "$LFS" == "/mnt/lfs" ]]; then
	echo "ERROR: LFS var is not set correctly, please restart the system and run lfs-setup.sh!"
	exit
fi

# create log

if ! [ -f $LFS"/src/debug/log" ]; then
	mkdir -v $LFS/src/debug
	touch $LFS/src/debug/log
fi

# get packages

if ! [[ "$1" == "compile" ]]; then
	echo "downloading packages:"
	wget --input-file=lfs-wget-list --continue --show-progress -q --directory-prefix=$LFS/src | tee $LFS/src/debug/log
	echo "all packages downloaded."
fi

# verify packages

echo "checking integrity of files..."
cp ./lfs-md5sums $LFS/src/
cd $LFS/src

if ! md5sum -c lfs-md5sums; then
	echo "ERROR: md5sums do not match, files may be corrupted!"
	exit
fi

# set owner of packages to root user

sudo chown root:root $LFS/src/*

# compile

# Binutils-2.42 - Pass 1
echo "compiling binutils-2.42."
tar -xvf binutils-2.42.tar.xz
cd binutils-2.42/
mkdir -v build
cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-default-hash-style=gnu
make
make install
cd $LFS/src
rm -rf binutils-2.42

#  GCC-13.2.0 - Pass 1
echo "compiling gcc-13.2.0."
tar -xvf gcc-13.2.0.tar.xz
cd gcc-13.2.0/
tar -xf ../mpfr-4.2.1.tar.xz
mv -v mpfr-4.2.1 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc
set +o posix
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
mkdir -v build
cd build
../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.39 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++
make
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
cd $LFS/src

# Linux-6.7.4 API Headers
echo "installing linux-6.7.4 API headers."
tar -xvf linux-6.7.4.tar.xz
cd linux-6.7.4/
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/src
rm -rf linux-6.7.4

# Glibc-2.39
echo "compiling glibc-2.39."
tar -xvf glibc-2.39.tar.xz
cd glibc-2.39/
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac
patch -Np1 -i ../glibc-2.39-fhs-1.patch
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.19               \
      --with-headers=$LFS/usr/include    \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib
make
make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
echo "performing sanity check..."
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
rm -v a.out
cd $LFS/src
rm -rf glibc-2.39

# Libstdc++ from GCC-13.2.0
echo "installing libstdc++."
cd gcc-13.2.0/
rm -r build
mkdir -v build
cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/13.2.0
make
make DESTDIR=$LFS install
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
cd $LFS/src
rm -rf gcc-13.2.0

# pass off to next shell script

echo "lfs toolchain has been built."
echo "passing to lfs-temp-tools.sh"
bash lfs-temp-tools.sh
