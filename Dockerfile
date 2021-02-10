# docker run -it dockcross/windows-x64-posix:latest /bin/bash
# docker images --digests | grep dockcross/windows-static-x64-posix
# FROM dockcross/windows-static-x64-posix:latest
# Previous SHA:
# - 14fb6d86d7ca39f6129b362f795c3e0d6c660ae1a8898325d274c20e2e955f5c -> gcc5.5 version
# - a29c4145e0a61b476854bc64731d269d35a35bef5d4ad7504c565da01567c72e -> tag: 20210109-7e58f93, gcc10.2 version

FROM dockcross/windows-static-x64-posix@sha256:a29c4145e0a61b476854bc64731d269d35a35bef5d4ad7504c565da01567c72e

RUN mkdir -p /opt
WORKDIR /opt

# MXE packages: Bzip2, BOOST, OpenSSL, ZLib
RUN cd /usr/src/mxe && \
    make TARGET=x86_64-w64-mingw32.static.posix bzip2 && \
    make TARGET=x86_64-w64-mingw32.static.posix boost && \
    make TARGET=x86_64-w64-mingw32.static.posix openssl && \
    make TARGET=x86_64-w64-mingw32.static.posix zlib && \
    rm -rf /usr/src/mxe/pkg/*

# BOOST Geometry extension
RUN git clone https://github.com/boostorg/geometry && \
    cd geometry && \
    git checkout 4aa61e59a72b44fb3c7761066d478479d2dd63a0 && \
    cp -rf include/boost/geometry/extensions /usr/src/mxe/usr/x86_64-w64-mingw32.static.posix/include/boost/geometry/. && \
    cd .. && \
    rm -rf geometry

# Ipopt 3.12 is the last version to ship thirdpary dependencies
# Ipopt 3.13 and higher require to download
# Using GFortan 10 requires additional Fortran flags for Mumps 4.10
# See https://github.com/coin-or-tools/ThirdParty-Mumps/issues/4
# http://www.coin-or.org/Ipopt/documentation/node10.html
# Command 'make test' is disabled : wine has to be used to run tests
RUN wget http://www.coin-or.org/download/source/Ipopt/Ipopt-3.12.9.tgz -O ipopt_src.tgz && \
    mkdir -p /opt/CoinIpopt && \
    mkdir -p ipopt_src && \
    tar -xf ipopt_src.tgz --strip 1 -C ipopt_src && \
    rm -rf ipopt_src.tgz && \
    cd ipopt_src && \
    cd ThirdParty/Blas && \
        ./get.Blas && \
    cd ../Lapack && \
        ./get.Lapack && \
    cd ../Mumps && \
        ./get.Mumps && \
    cd ../../ && \
    mkdir build && \
    cd build && \
    CC=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static.posix-gcc \
    CXX=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static.posix-g++ \
    F77=/usr/src/mxe/usr/bin/x86_64-w64-mingw32.static.posix-gfortran \
    ADD_FFLAGS=-fallow-argument-mismatch \
    ../configure \
        --disable-shared \
        --prefix=/opt/CoinIpopt \
        --host=x86_64-w64-mingw32 \
        && \
    make && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf ipopt_src

RUN wget https://github.com/eigenteam/eigen-git-mirror/archive/3.3.7.tar.gz -O eigen.tgz && \
    mkdir -p /opt/eigen && \
    tar -xzf eigen.tgz --strip 1 -C /opt/eigen && \
    rm -rf eigen.tgz

RUN wget https://github.com/jbeder/yaml-cpp/archive/release-0.3.0.tar.gz -O yaml_cpp.tgz && \
    mkdir -p /opt/yaml_cpp && \
    tar -xzf yaml_cpp.tgz --strip 1 -C /opt/yaml_cpp && \
    rm -rf yaml_cpp.tgz

RUN wget https://github.com/google/googletest/archive/release-1.8.1.tar.gz -O googletest.tgz && \
    mkdir -p /opt/googletest && \
    tar -xzf googletest.tgz --strip 1 -C /opt/googletest && \
    rm -rf googletest.tgz

RUN wget https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz -O websocketpp.tgz && \
    mkdir -p /opt/websocketpp && \
    tar -xzf websocketpp.tgz --strip 1 -C /opt/websocketpp && \
    rm -rf websocketpp.tgz

RUN mkdir -p /opt/libf2c && \
    cd /opt/libf2c && \
    wget http://www.netlib.org/f2c/libf2c.zip -O libf2c.zip && \
    unzip libf2c.zip && \
    rm -rf libf2c.zip

RUN wget https://sourceforge.net/projects/geographiclib/files/distrib/archive/GeographicLib-1.30.tar.gz/download -O geographiclib.tgz && \
    mkdir -p /opt/geographiclib && \
    tar -xzf geographiclib.tgz --strip 1 -C /opt/geographiclib && \
    rm -rf geographiclib.tgz

RUN cd /opt && \
    git clone https://github.com/garrison/eigen3-hdf5 && \
    cd eigen3-hdf5 && \
    git checkout 2c782414251e75a2de9b0441c349f5f18fe929a2

# HDF5 with C/C++/Fortran support Version 1.8.20. Higher versions are incompatible with eigen-hdf5
RUN wget https://support.hdfgroup.org/ftp/HDF5/prev-releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz -O hdf5_src.tar.gz && \
    mkdir -p HDF5_SRC && \
    tar -xf hdf5_src.tar.gz --strip 1 -C HDF5_SRC && \
    cd HDF5_SRC && \
    echo "COMMENT Patch CMakeLists.txt to avoid warning message for each compiled file" && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    awk 'NR==3{print "ADD_DEFINITIONS(-DH5_HAVE_RANDOM=0)"}1' CMakeListsORI.txt > CMakeLists.txt && \
    echo "COMMENT diff CMakeListsORI.txt CMakeLists.txt" && \
    rm CMakeListsORI.txt && \
    echo "COMMENT Patch src/CMakeLists.txt to work with wine when running a program while configuring/compiling" && \
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    echo "COMMENT diff CMakeListsORI.txt CMakeLists.txt" && \
    cd .. && \
    echo "COMMENT Patch fortran/src/CMakeLists.txt" && \
    cd fortran && \
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    echo "COMMENT diff CMakeListsORI.txt CMakeLists.txt" && \
    cd .. && \
    cd .. && \
    echo "COMMENT Patch hl/fortran/src/CMakeLists.txt" && \
    cd hl && \
    cd fortran && \
    cd src && \
    cp CMakeLists.txt CMakeListsORI.txt && \
    sed -i 's/COMMAND\ \${CMD}/COMMAND wine \${CMD}/g' CMakeLists.txt && \
    echo "COMMENT diff CMakeListsORI.txt CMakeLists.txt" && \
    cd .. && \
    cd .. && \
    cd .. && \
    echo "COMMENT Move back" && \
    cd .. && \
    mkdir -p HDF5_build && \
    cd HDF5_build && \
    cmake \
      -DCMAKE_BUILD_TYPE:STRING=Release \
      -DCMAKE_INSTALL_PREFIX:PATH=/opt/HDF5_1_8_20 \
      -DBUILD_SHARED_LIBS:BOOL=ON \
      -DBUILD_TESTING:BOOL=OFF \
      -DHDF5_BUILD_EXAMPLES:BOOL=OFF \
      -DHDF5_BUILD_HL_LIB:BOOL=ON \
      -DHDF5_BUILD_CPP_LIB:BOOL=ON \
      -DHDF5_BUILD_FORTRAN:BOOL=ON \
      ../HDF5_SRC && \
    echo "COMMENT Patch cmake files" && \
    echo "COMMENT http://hdf-forum.184993.n3.nabble.com/Compilation-of-HDF5-1-10-1-with-MSYS-and-MiNGW-td4029696.html" && \
    echo "COMMENT sed -i 's/\r//g' H5config_f.inc" && \
    echo "COMMENT sed -i 's/\r//g' fortran/H5fort_type_defines.h" && \
    make && \
    echo "COMMENT Fixed Fortran mod install bug" && \
    mkdir -p bin/static/Release && \
    cp bin/static/*.mod bin/static/Release/. && \
    mkdir -p bin/shared/Release && \
    cp bin/static/*.mod bin/shared/Release/. && \
    make install && \
    cd .. && \
    rm -rf HDF5_build && \
    rm -rf HDF5_SRC && \
    rm -rf hdf5_src.tar.gz

# Install GRPC with its dependencies
# C-Ares
RUN wget https://github.com/c-ares/c-ares/releases/download/cares-1_15_0/c-ares-1.15.0.tar.gz -O cares_src.tgz && \
    mkdir -p /opt/CAres && \
    mkdir -p cares_src && \
    tar -xf cares_src.tgz --strip 1 -C cares_src && \
    rm -rf cares_src.tgz && \
    cd cares_src && \
    mkdir cares_build && \
    cd cares_build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/opt/CAres \
        -DCARES_STATIC:BOOL=ON \
        -DCARES_SHARED:BOOL=OFF \
    && \
    make && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf cares_src

# Patch macro _WIN32_WINNT that defines the Windows version in _mingw.h
# GRPC requires at least 0x600, we change this value manually
RUN cd / && \
echo '--- /usr/src/mxe/usr/x86_64-w64-mingw32.static.posix/include/_mingw.h      2019-04-14 20:27:59.209176000 +0000\n\
+++ /usr/src/mxe/usr/x86_64-w64-mingw32.static.posix/include/_mingw.h   2019-04-14 20:28:34.934280000 +0000\n\
@@ -229,7 +229,7 @@\n\
 \n\
 \n\
 \#ifndef _WIN32_WINNT\n\
-\#define _WIN32_WINNT 0x502\n\
+\#define _WIN32_WINNT 0x600\n\
 \#endif\n\
 \n\
 \#ifndef _INT128_DEFINED\n'\
> p.patch && \
sed -i 's/\\#/#/g' p.patch && \
patch -p0 < p.patch && \
rm p.patch

# GRPC
ENV GRPC_RELEASE_TAG v1.20.0
RUN mkdir -p /opt/.wine && \
    export WINEPREFIX=/opt/.wine && \
    wine winecfg && \
    git clone -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /opt/grpc_src && \
    cd /opt/grpc_src && \
    git submodule update --init && \
    cd /opt/grpc_src && \
echo '--- include/grpc/impl/codegen/port_platform.h      2019-04-14 12:26:20.932354000 +0000\n\
+++ include/grpc/impl/codegen/port_platform_new.h  2019-04-14 12:26:40.121945000 +0000\n\
@@ -39,6 +39,8 @@\n\
 \#define NOMINMAX\n\
 \#endif /* NOMINMAX */\n\
 \n\
+\#include <windows.h>\n\
+\n\
 \#ifndef _WIN32_WINNT\n\
 \#error \\\n\
     "Please compile grpc with _WIN32_WINNT of at least 0x600 (aka Windows Vista)"\n\
@@ -49,8 +51,6 @@\n\
 \#endif /* _WIN32_WINNT < 0x0600 */\n\
 \#endif /* defined(_WIN32_WINNT) */\n\
 \n\
-\#include <windows.h>\n\
-\n\
 \#ifdef GRPC_WIN32_LEAN_AND_MEAN_WAS_NOT_DEFINED\n\
 \#undef GRPC_WIN32_LEAN_AND_MEAN_WAS_NOT_DEFINED\n\
 \#undef WIN32_LEAN_AND_MEAN\n'\
> p.patch && \
sed -i 's/\\#/#/g' p.patch && \
patch -p0 < p.patch && \
rm p.patch && \
cd /opt/grpc_src/ && \
    echo "--- installing grpc ---" && \
    cd /opt/grpc_src/third_party/protobuf && \
    cd cmake && \
    mkdir build && \
    cd build && \
    cmake .. \
        -Dprotobuf_BUILD_TESTS:BOOL=OFF \
        -Dprotobuf_BUILD_CONFORMANCE:BOOL=OFF \
        -Dprotobuf_BUILD_EXAMPLES:BOOL=OFF \
        -Dprotobuf_BUILD_PROTOC_BINARIES:BOOL=ON \
        -DBUILD_SHARED_LIBS:BOOL=OFF \
        -Dprotobuf_BUILD_SHARED_LIBS_DEFAULT:BOOL=OFF \
        -Dprotobuf_WITH_ZLIB_DEFAULT:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX=/opt/ProtoBuf \
    && \
    make install && \
    cd .. && \
    cd .. && \
    cd ../.. && \
    cd /opt/grpc_src && \
    echo "--- installing grpc ---" && \
    cd /opt/grpc_src && \
    sed -i 's/Windows/windows/g' third_party/benchmark/src/colorprint.cc && \
    sed -i 's/Windows/windows/g' third_party/benchmark/src/sleep.cc && \
    sed -i 's/Shlwapi/shlwapi/g' third_party/benchmark/src/sysinfo.cc && \
    sed -i 's/VersionHelpers/versionhelpers/g' third_party/benchmark/src/sysinfo.cc && \
    sed -i 's/Windows/windows/g' third_party/benchmark/src/sysinfo.cc && \
    sed -i 's/Shlwapi/shlwapi/g' third_party/benchmark/src/timers.cc && \
    sed -i 's/VersionHelpers/versionhelpers/g' third_party/benchmark/src/timers.cc && \
    sed -i 's/Windows/windows/g' third_party/benchmark/src/timers.cc && \
    sed -i 's/IswindowsXPOrGreater/IsWindowsXPOrGreater/g' third_party/benchmark/src/sysinfo.cc && \
    sed -i 's/Shlwapi/shlwapi/g' third_party/benchmark/src/CMakeLists.txt && \
    sed -i 's/COMMAND\ \${_gRPC_PROTOBUF_PROTOC_EXECUTABLE}/COMMAND wine \/opt\/ProtoBuf\/bin\/protoc.exe-3.7.0.0/g' CMakeLists.txt && \
    sed -i 's/set(_gRPC_CPP_PLUGIN \$<TARGET_FILE:grpc_cpp_plugin>)/set(_gRPC_CPP_PLUGIN \$\{CMAKE_CURRENT_BINARY_DIR\}\/grpc_cpp_plugin.exe)/g' CMakeLists.txt && \
    sed -i 's/generate_mock_code=true:\$/generate_mock_code=true:Z:\$/g' CMakeLists.txt && \
    sed -i 's/cpp_out=\$/cpp_out=Z:\$/g' CMakeLists.txt && \
    sed -i 's/\${_gRPC_PROTOBUF_WELLKNOWN_INCLUDE_DIR}/Z:\${_gRPC_PROTOBUF_WELLKNOWN_INCLUDE_DIR}/g' CMakeLists.txt && \
    sed -i 's/find_package(Protobuf REQUIRED \${gRPC_PROTOBUF_PACKAGE_TYPE})/find_package(Protobuf REQUIRED PATHS \/opt\/ProtoBuf\/lib\/cmake)/g' cmake/protobuf.cmake && \
    mkdir grpc_build && \
    cd grpc_build && \
    cmake .. \
        -DgRPC_INSTALL:BOOL=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/GRPC \
        -DCMAKE_CROSSCOMPILING:BOOL=OFF \
        -DgRPC_BUILD_CSHARP_EXT:BOOL=OFF \
        -DgRPC_BUILD_TESTS:BOOL=OFF \
        -DgRPC_BUILD_CODEGEN:BOOL=ON \
        -DgRPC_BACKWARDS_COMPATIBILITY_MODE:BOOL=OFF \
        -DgRPC_ZLIB_PROVIDER:STRING=package \
        -DZLIB_ROOT:PATH=/usr/src/mxe/usr/x86_64-w64-mingw32.static.posix \
        -DgRPC_PROTOBUF_PROVIDER:STRING=package \
        -DgRPC_PROTOBUF_PACKAGE_TYPE:PATH=/opt/ProtoBuf/lib/cmake/protobuf \
        -DProtobuf_DIR:PATH=/opt/ProtoBuf/lib/cmake/protobuf \
        -DgRPC_CARES_PROVIDER:STRING=package \
        -Dc-ares_DIR:PATH=/opt/CAres/lib/cmake/c-ares \
        -DgRPC_SSL_PROVIDER:STRING=package \
        -DOPENSSL_ROOT_DIR:PATH=/usr/src/mxe/usr/x86_64-w64-mingw32.static.posix \
    && \
    make grpc_cpp_plugin && \
    make && \
    make install && \
    cd .. && \
    cd .. && \
    rm -rf /opt/grpc_src
