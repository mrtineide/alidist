package: JAliEn-ROOT
version: "%(tag_basename)s"
tag: "0.7.21"
source: https://gitlab.cern.ch/jalien/jalien-root.git
requires:
  - ROOT
  - xjalienfs
  - XRootD
  - libwebsockets
  - libuv
license: GPL-3.0
build_requires:
  - json-c
  - CMake
  - ninja
  - "GCC-Toolchain:(?!osx)"
  - zlib
  - Alice-GRID-Utils
  - alibuild-recipe-tools
append_path:
  ROOT_PLUGIN_PATH: "$JALIEN_ROOT_ROOT/etc/plugins"
  ROOT_INCLUDE_PATH: "$JALIEN_ROOT_ROOT/include"
---
#!/bin/bash -e
SONAME=so
case $ARCHITECTURE in
  osx*)
        SONAME=dylib
	[[ ! $OPENSSL_ROOT ]] && OPENSSL_ROOT=$(brew --prefix openssl@3)
	[[ ! $LIBWEBSOCKETS_ROOT ]] && LIBWEBSOCKETS_ROOT=$(brew --prefix libwebsockets)
  ;;
esac

# This is needed to support old version which did not have FindAliceGridUtils.cmake
ALIBUILD_CMAKE_BUILD_DIR=$SOURCEDIR
if [ ! -f "$JALIEN_ROOT_ROOT/cmake/modules/FindAliceGridUtils.cmake" ]; then
  ALIBUILD_CMAKE_BUILD_DIR="$BUILDDIR"
  rsync -a --exclude .git --delete --delete-excluded "$SOURCEDIR/" "$BUILDDIR"
  rsync -a --exclude "module.modulemap" "$ALICE_GRID_UTILS_ROOT/include/" "$BUILDDIR/inc"
fi

cmake "$ALIBUILD_CMAKE_BUILD_DIR"                        \
      -G Ninja                                           \
      -DCMAKE_BUILD_TYPE=Debug                           \
      -DCMAKE_INSTALL_PREFIX="$INSTALLROOT"              \
      ${CXXSTD:+-DCMAKE_CXX_STANDARD=${CXXSTD}}          \
      -DROOTSYS="$ROOTSYS"                               \
      -DJSONC="$JSON_C_ROOT"                             \
      -DALICE_GRID_UTILS_ROOT="$ALICE_GRID_UTILS_ROOT"   \
       ${OPENSSL_ROOT:+-DOPENSSL_ROOT_DIR=$OPENSSL_ROOT} \
       ${OPENSSL_ROOT:+-DOPENSSL_INCLUDE_DIRS=$OPENSSL_ROOT/include} \
       ${OPENSSL_ROOT:+-DOPENSSL_LIBRARIES=$OPENSSL_ROOT/lib/libssl.$SONAME;$OPENSSL_ROOT/lib/libcrypto.$SONAME} \
      -DZLIB_ROOT="$ZLIB_ROOT"                           \
      -DXROOTD_ROOT_DIR="$XROOTD_ROOT"                   \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON                 \
      -DLWS="$LIBWEBSOCKETS_ROOT"
cmake --build . -- ${JOBS:+-j $JOBS} install

cp ${BUILDDIR}/compile_commands.json ${INSTALLROOT}

DEVEL_SOURCES="`readlink $SOURCEDIR || echo $SOURCEDIR`"
# This really means we are in development mode. We need to make sure we
# use the real path for sources in this case. We also copy the
# compile_commands.json file so that IDEs can make use of it directly, this
# is a departure from our "no changes in sourcecode" policy, but for a good reason
# and in any case the file is in gitignore.
if [ "$DEVEL_SOURCES" != "$SOURCEDIR" ]; then
  perl -p -i -e "s|$SOURCEDIR|$DEVEL_SOURCES|" compile_commands.json
  ln -sf $BUILDDIR/compile_commands.json $DEVEL_SOURCES/compile_commands.json
fi
# Modulefile
mkdir -p etc/modulefiles
alibuild-generate-module --lib --cmake > "etc/modulefiles/$PKGNAME"
cat >> "etc/modulefiles/$PKGNAME" <<EoF
# Our environment
append-path ROOT_PLUGIN_PATH \$PKG_ROOT/etc/plugins
prepend-path ROOT_INCLUDE_PATH \$PKG_ROOT/include
EoF
mkdir -p $INSTALLROOT/etc/modulefiles && rsync -a --delete etc/modulefiles/ $INSTALLROOT/etc/modulefiles
