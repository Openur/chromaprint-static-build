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

export FFMPEG_DIR=$(readlink -f -- "$BASE_DIR/../ffmpeg/artifacts/ffmpeg-${FFMPEG_VERSION}-linux-${ARCH}/opt/ffmpeg")

: ${FFMPEG_DIR:?}

if [ ! -e "$CHROMAPRINT_TARBALL" ]; then
  curl -s -L -O "$CHROMAPRINT_TARBALL_URL"
fi

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar xf "$BASE_DIR/$CHROMAPRINT_TARBALL" --strip-components=1

CHROMAPRINT_CMAKE_ARGS+=(
  -DCMAKE_C_FLAGS='-static -static-libgcc -static-libstdc++'
  -DCMAKE_CXX_FLAGS='-static -static-libgcc -static-libstdc++'
)

case "$ARCH" in
  arm)
    sed -i -e 's!{EXTRA_PATHS}!${EXTRA_PATHS}!g' "$BUILD_DIR/package/toolchain-armhf.cmake.in"

    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/package/toolchain-armhf.cmake.in"
      -DEXTRA_PATHS="$FFMPEG_DIR"
    )
    ;;
  arm64)
    sed -i -e 's!{EXTRA_PATHS}!${EXTRA_PATHS}!g' "$BUILD_DIR/package/toolchain-aarch64.cmake.in"

    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/package/toolchain-aarch64.cmake.in"
      -DEXTRA_PATHS="$FFMPEG_DIR"
    )
    ;;
  x64)
    ;;
  *)
    echo "Unknown architecture: $ARCH"
    exit 1
    ;;
esac

cmake "${CHROMAPRINT_CMAKE_ARGS[@]}" .

make -j$(nproc) V=1
make DESTDIR="$BASE_DIR/artifacts" install/strip
