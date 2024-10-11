#!/bin/sh

python_dir=Python-${PYTHON_VERSION}
python_tgz=${python_dir}.tgz
python_url=https://www.python.org/ftp/python/${PYTHON_VERSION}/${python_tgz}

if test $(which chrpath >/dev/null) -ne 0; then
    sudo apt-get install chrpath
fi

if test $(which patchelf >/dev/null) -ne 0; then
   rpath_cmd="patchelf --set-rpath"
else
   rpath_cmd="chrpath -r"
fi

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

cwd=$(pwd)
release_dir=${cwd}/zuspec-python-${version}

if test -d ${release_dir}; then
  rm -rf ${release_dir}
fi

mkdir $release_dir

cd $cwd/${python_dir}

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

${rpath_cmd} python3.[0-9][0-9] '$ORIGIN/../lib'

#cd $release_dir/lib
#
#for file in lib*; do
#  if test -f $file and test $(file -i ${file} | grep sharedlib | wc -l) -ne 0; then
#    ${rpath_cmd} $file
#  fi
#done

cd $release_dir/lib/python*/lib-dynload
for f in *.so; do
  ${rpath_cmd} $file '$ORIGIN/../../'
done

cd $cwd
tar czf zuspec-python-${PYTHON_VERSION}.tar.gz zuspec-python-${PYTHON_VERSION}
