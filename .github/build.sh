#!/usr/bin/env bash

set -e

cd $(dirname "$0")/..

mkdir -p build/dist
cd build

#--

echo '::group::Install dependencies'

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
  autoconf \
  automake \
  bison \
  ca-certificates \
  curl \
  cmake \
  make \
  gfortran \
  libfl-dev \
  libfftw3-dev \
  libsuitesparse-dev \
  libblas-dev \
  liblapack-dev \
  libtool

echo '::endgroup::'

#--

export XYCE_OUTDIR=/usr/local/
export PATH="${PATH}:/tmp/xyce${XYCE_OUTDIR}bin"
export LIBRARY_PATH="${LIBRARY_PATH}:/tmp/xyce${XYCE_OUTDIR}lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/tmp/xyce${XYCE_OUTDIR}lib"
export CPATH="${CPATH}:/tmp/xyce${XYCE_OUTDIR}include"

#--

echo '::group::Get Trilinos and Xyce sources'

mkdir -p Trilinos/trilinos-source
curl -fsSL https://github.com/trilinos/Trilinos/archive/trilinos-release-12-12-1.tar.gz | \
  tar xz -C Trilinos/trilinos-source --strip-components=1 \

mkdir -p Xyce
curl -fsSL https://codeload.github.com/Xyce/Xyce/tar.gz/Release-${XYCE_VERSION} | \
  tar xz -C Xyce --strip-components=1

echo '::endgroup::'

#--

echo '::group::Build Trilinos'

FLAGS="-O3 -fPIC"

cd Trilinos

cmake \
  -G "Unix Makefiles" \
  -DCMAKE_CXX_FLAGS="$FLAGS" \
  -DCMAKE_C_FLAGS="$FLAGS" \
  -DCMAKE_Fortran_FLAGS="$FLAGS" \
  -DCMAKE_INSTALL_PREFIX="$XYCE_OUTDIR" \
  -DCMAKE_MAKE_PROGRAM="make" \
  -DBUILD_SHARED_LIBS=ON \
  -DTrilinos_ENABLE_EXPLICIT_INSTANTIATION=ON \
  -DTrilinos_ENABLE_NOX=ON \
    -DNOX_ENABLE_LOCA=ON \
  -DTrilinos_ENABLE_EpetraExt=ON \
    -DEpetraExt_BUILD_BTF=ON \
    -DEpetraExt_BUILD_EXPERIMENTAL=ON \
    -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
  -DTrilinos_ENABLE_TrilinosCouplings=ON \
  -DTrilinos_ENABLE_Ifpack=ON \
  -DTrilinos_ENABLE_AztecOO=ON \
  -DTrilinos_ENABLE_Belos=ON \
  -DTrilinos_ENABLE_Teuchos=ON \
    -DTeuchos_ENABLE_COMPLEX=ON \
  -DTrilinos_ENABLE_Amesos=ON \
    -DAmesos_ENABLE_KLU=ON \
  -DTrilinos_ENABLE_Amesos2=ON \
    -DAmesos2_ENABLE_KLU2=ON \
    -DAmesos2_ENABLE_Basker=ON \
  -DTrilinos_ENABLE_Sacado=ON \
  -DTrilinos_ENABLE_Stokhos=ON \
  -DTrilinos_ENABLE_Kokkos=ON \
  -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
  -DTrilinos_ENABLE_CXX11=ON \
  -DTPL_ENABLE_AMD=ON \
  -DAMD_LIBRARY_DIRS="/usr/lib" \
  -DTPL_AMD_INCLUDE_DIRS="/usr/include/suitesparse" \
  -DTPL_ENABLE_BLAS=ON \
  -DTPL_ENABLE_LAPACK=ON \
  ./trilinos-source

make DESTDIR=dist -j$(nproc) install

cd ..

echo '::endgroup::'

#--

echo '::group::Build Xyce'

xyceBuildDir=/src/build/xyce-build/

cd Xyce

./bootstrap

mkdir xyce-build

cd xyce-build

../configure \
  CXXFLAGS="-O3" \
  LDFLAGS="-Wl,-rpath=$xyceBuildDir/utils/XyceCInterface -Wl,-rpath=$xyceBuildDir/lib" \
  CPPFLAGS="-I/usr/include/suitesparse" \
  ARCHDIR=$XYCE_OUTDIR \
  --enable-shared \
  --enable-xyce-shareable \
  --enable-stokhos \
  --enable-amesos2
make DESTDIR=../../dist -j$(nproc) install

cd ../..

echo '::endgroup::'

tree dist
