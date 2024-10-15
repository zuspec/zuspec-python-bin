#!/bin/sh -x

scripts_dir=$(dirname $(realpath $0))
project_dir=$(dirname ${scripts_dir})

openssl_version=3.3.1
openssl_dir=openssl-${openssl_version}
openssl_tgz="${openssl_dir}.tar.gz"
openssl_url="https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/${openssl_tgz}"
libffi_dir=libffi-3.4.5
libffi_tgz="${libffi_dir}.tar.gz"
libffi_url="https://github.com/libffi/libffi/releases/download/v3.4.5/${libffi_tgz}"

sqlite_dir="sqlite-autoconf-3460000"
sqlite_tgz="${sqlite_dir}.tar.gz"
sqlite_url="https://www.sqlite.org/2024/${sqlite_tgz}"


python_version_short=$(echo $PYTHON_VERSION | sed -e 's/^\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/')

python_dir=Python-${PYTHON_VERSION}
python_tgz=${python_dir}.tgz
python_url=https://www.python.org/ftp/python/${PYTHON_VERSION}/${python_tgz}

if test $(which chrpath >/dev/null) -ne 0; then
    sudo apt-get install chrpath
fi

which patchelf >/dev/null
if test $? -eq 0; then
   rpath_cmd="patchelf --set-rpath"
else
   rpath_cmd="chrpath -r"
fi

echo "rpath_cmd: ${rpath_cmd}"

#** Clean up
if test "x${BUILD_NUM}" != "x"; then
    release_dir=${project_dir}/zuspec-python-${PYTHON_VERSION}.${BUILD_NUM}
else
    release_dir=${project_dir}/zuspec-python-${PYTHON_VERSION}
fi

if test -d ${release_dir}; then
  rm -rf ${release_dir}
fi

#********************************************************************
#* 1. Build openssl
#********************************************************************
cd ${project_dir}
if test ! -f ${openssl_tgz}; then
    echo "Downloading openssl"
    wget ${openssl_url}
    if test $? -ne 0; then exit 1; fi
fi

if test -d ${openssl_dir}; then
  rm -rf ${openssl_dir}
fi

echo "Unpack openssl"
tar xf ${openssl_tgz}
if test $? -ne 0; then exit 1; fi

cd ${openssl_dir}
./config --prefix=${release_dir}
if test $? -ne 0; then exit 1; fi

make -j$(nproc)
if test $? -ne 0; then exit 1; fi
make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* 2. Build libffi
#********************************************************************
cd ${project_dir}

if test ! -f ${libffi_tgz}; then
    echo "Downloading libffi"
    wget ${libffi_url}
    if test $? -ne 0; then exit 1; fi
fi

if test -d ${libffi_dir}; then
  rm -rf ${libffi_dir}
fi

echo "Unpack libffi"
tar xf ${libffi_tgz}
if test $? -ne 0; then exit 1; fi

cd ${libffi_dir}
./configure --prefix=${release_dir}
if test $? -ne 0; then exit 1; fi

make -j$(nproc)
if test $? -ne 0; then exit 1; fi
make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* 3. Build sqlite
#********************************************************************
cd ${project_dir}
if test ! -f ${sqlite_tgz}; then
    echo "Downloading sqlite"
    wget ${sqlite_url}
    if test $? -ne 0; then exit 1; fi
fi

if test -d ${sqlite_dir}; then
    rm -rf ${sqlite_dir}
fi

tar xf ${sqlite_tgz}
if test $? -ne 0; then exit 1; fi

cd ${sqlite_dir}
./configure --prefix=${release_dir}
if test $? -ne 0; then exit 1; fi

make -j$(nproc)
if test $? -ne 0; then exit 1; fi
make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* 4. Build Python
#********************************************************************
cd ${project_dir}

if test ! -f ${python_tgz}; then
    wget $python_url
    if test $? -ne 0; then exit 1; fi
fi

if test -d ${python_dir}; then
    rm -rf ${python_dir}
fi

tar xvf ${python_tgz}

version=${PYTHON_VERSION}
if test "x${BUILD_NUM}" != "x"; then
  version="${version}-${PYTHON_VERSION}"
fi


mkdir $release_dir

cd ${project_dir}/${python_dir}

./configure --prefix=${release_dir} --enable-optimizations --enable-shared
if test $? -ne 0; then exit 1; fi

make -j$(expr 2 * $(nproc))
if test $? -ne 0; then exit 1; fi

make install
if test $? -ne 0; then exit 1; fi

#********************************************************************
#* Clean up and package
#********************************************************************
cd $release_dir/bin
if test $? -ne 0; then exit 1; fi

${rpath_cmd} '$ORIGIN/../lib:$ORIGIN/../lib64' python${python_version_short}
if test $? -ne 0; then exit 1; fi

cd $release_dir/lib
for lib in *.so; do
  ${rpath_cmd} '$ORIGIN:$ORIGIN/../lib64' $lib
done

cd $release_dir/lib64
for lib in *.so; do
  ${rpath_cmd} '$ORIGIN:$ORIGIN/../lib' $lib
done


#cd $release_dir/lib
#
#for file in lib*; do
#  if test -f $file and test $(file -i ${file} | grep sharedlib | wc -l) -ne 0; then
#    ${rpath_cmd} $file
#  fi
#done

cd $release_dir/lib/python*/lib-dynload
for f in *.so; do
  ${rpath_cmd} '$ORIGIN/../../../lib:$ORIGIN/../../../lib64' ${f}
done

cd ${project_dir}
tar czf zuspec-python-${PYTHON_VERSION}.tar.gz zuspec-python-${PYTHON_VERSION}
