#!/usr/bin/env bash

set -eux

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

: ${ARCH?}
: ${FFMPEG_VERSION?}
: ${FFMPEG_TARBALL?}
: ${FFMPEG_TARBALL_URL?}

readonly OUTPUT_DIR="artifacts/ffmpeg-${FFMPEG_VERSION}-macos-${ARCH}"

if [ ! -e "$FFMPEG_TARBALL" ]; then
  curl -s -L -O "$FFMPEG_TARBALL_URL"
fi

FFMPEG_CONFIGURE_ARGS+=(
  --pkg-config-flags="--static"
  --target-os=darwin
  --cc=clang
  --enable-runtime-cpudetect
)

case "$ARCH" in
  arm64)
    FFMPEG_CONFIGURE_ARGS+=(
      --arch=arm64
      --extra-cflags="-arch arm64 -mmacosx-version-min=13"
      --extra-ldflags="-arch arm64 -mmacosx-version-min=13"
    )
    ;;
  x64)
    FFMPEG_CONFIGURE_ARGS+=(
      --arch=x86_64
      --extra-cflags="-arch x86_64 -mmacosx-version-min=10.13"
      --extra-ldflags="-arch x86_64 -mmacosx-version-min=10.13"
      --enable-cross-compile
      --disable-x86asm
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

PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
  ./configure "${FFMPEG_CONFIGURE_ARGS[@]}" || (tail -n 50 ffbuild/config.log && exit 1)

make V=1
make DESTDIR="$BASE_DIR/$OUTPUT_DIR" install
