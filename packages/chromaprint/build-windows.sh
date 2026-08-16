#!/usr/bin/env bash

set -eux

cd $(dirname $0)
BASE_DIR=$(pwd)

source ../common.sh

: ${ARCH?}
: ${CHROMAPRINT_VERSION?}
: ${FFMPEG_VERSION?}
: ${CHROMAPRINT_TARBALL?}
: ${CHROMAPRINT_TARBALL_URL?}

export FFMPEG_DIR=$(readlink -f -- "$BASE_DIR/../ffmpeg/artifacts/ffmpeg-${FFMPEG_VERSION}-windows-${ARCH}/opt/ffmpeg")

: ${FFMPEG_DIR:?}

if [ ! -e "$CHROMAPRINT_TARBALL" ]; then
  curl -s -L -O "$CHROMAPRINT_TARBALL_URL"
fi

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar xf "$BASE_DIR/$CHROMAPRINT_TARBALL" --strip-components=1

sed -i -e 's!{EXTRA_PATHS}!${EXTRA_PATHS}!g' -e 's!{ARCH}!${ARCH}!g' "$BUILD_DIR/package/toolchain-mingw.cmake.in"

CHROMAPRINT_CMAKE_ARGS+=(
  -G"Unix Makefiles"
)

case "$ARCH" in
  arm64)
    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/package/toolchain-mingw.cmake.in"
      -DCMAKE_C_FLAGS='-static -static-libgcc -static-libstdc++'
      -DCMAKE_CXX_FLAGS='-static -static-libgcc -static-libstdc++'
      -DARCH=aarch64
      -DEXTRA_PATHS="$FFMPEG_DIR"
    )
    ;;
  x64)
    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/package/toolchain-mingw.cmake.in"
      -DCMAKE_C_FLAGS='-static'
      -DCMAKE_CXX_FLAGS='-static'
      -DARCH=x86_64
      -DEXTRA_PATHS="$FFMPEG_DIR"
    )
    ;;
  x86)
    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/package/toolchain-mingw.cmake.in"
      -DCMAKE_C_FLAGS='-static -static-libgcc -static-libstdc++'
      -DCMAKE_CXX_FLAGS='-static -static-libgcc -static-libstdc++'
      -DARCH=i686
      -DEXTRA_PATHS="$FFMPEG_DIR"
    )
    ;;
  *)
    echo "Unknown architecture: $ARCH"
    exit 1
    ;;
esac

MSYS2_ARG_CONV_EXCL="-DCMAKE_INSTALL_PREFIX=" \
  cmake "${CHROMAPRINT_CMAKE_ARGS[@]}" .

make -j$(nproc) V=1
make DESTDIR="$BASE_DIR/artifacts" install/strip
