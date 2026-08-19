#!/usr/bin/env bash

set -eux

cd $(dirname $0)
BASE_DIR=$(pwd)

source ../common.sh

: ${ARCH?}
: ${FFMPEG_VERSION?}
: ${FFMPEG_TARBALL?}
: ${FFMPEG_TARBALL_URL?}

readonly OUTPUT_DIR="artifacts/ffmpeg-${FFMPEG_VERSION}-linux-musl-${ARCH}"

if [ ! -e "$FFMPEG_TARBALL" ]; then
  curl -s -L -O "$FFMPEG_TARBALL_URL"
fi

FFMPEG_CONFIGURE_ARGS+=(
  --pkg-config=pkg-config
  --pkg-config-flags="--static"
  --extra-ldexeflags="-static"
  --extra-libs="-lpthread -lm"
  --target-os=linux
)

case "$ARCH" in
  arm64)
    FFMPEG_CONFIGURE_ARGS+=(
      --arch=aarch64
    )
    ;;
  x64)
    FFMPEG_CONFIGURE_ARGS+=(
      --arch=x86_64
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

./configure "${FFMPEG_CONFIGURE_ARGS[@]}"

make -j$(nproc) V=1
make DESTDIR="$BASE_DIR/$OUTPUT_DIR" install
