#!/usr/bin/env bash

set -eux

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

: ${ARCH?}
: ${FFMPEG_VERSION?}
: ${FFMPEG_TARBALL?}
: ${FFMPEG_TARBALL_URL?}

readonly OUTPUT_DIR="artifacts/ffmpeg-${FFMPEG_VERSION}-win-${ARCH}"

if [ ! -e "$FFMPEG_TARBALL" ]; then
  curl -s -L -O "$FFMPEG_TARBALL_URL"
fi

FFMPEG_CONFIGURE_ARGS+=(
  --pkg-config=pkg-config
  --pkg-config-flags="--static"
  --extra-ldexeflags="-static"
  --extra-libs="-lpthread -lm"
  --target-os=mingw32
)

case "$ARCH" in
  arm64)
    export CMAKE_POLICY_VERSION_MINIMUM="3.5"

    FFMPEG_CONFIGURE_ARGS+=(
      --cc=clang
      --cxx=clang++
      --arch=arm64
    )
    ;;
  x64)
    export CMAKE_POLICY_VERSION_MINIMUM="3.5"

    FFMPEG_CONFIGURE_ARGS+=(
      --cc=clang
      --cxx=clang++
      --arch=x86_64
    )
    ;;
  x86)
    export CMAKE_POLICY_VERSION_MINIMUM="3.5"

    FFMPEG_CONFIGURE_ARGS+=(
      --arch=x86
      --enable-cross-compile
      --cross-prefix=i686-w64-mingw32-
      --ld="i686-w64-mingw32-g++-win32"
    )
    ;;
  *)
    echo "Unknown architecture: $ARCH"
    exit 1
    ;;
esac

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar xf "$BASE_DIR/$FFMPEG_TARBALL" --strip-components=1

PKG_CONFIG_PATH=/usr/x86_64-w64-mingw32/lib/pkgconfig:/usr/i686-w64-mingw32/lib/pkgconfig:${MINGW_PREFIX:-/clang64}/lib64/pkgconfig \
  ./configure "${FFMPEG_CONFIGURE_ARGS[@]}"

make -j$(nproc) V=1
make DESTDIR="$BASE_DIR/$OUTPUT_DIR" install
