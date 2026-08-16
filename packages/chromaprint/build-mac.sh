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

export FFMPEG_DIR=$(readlink -f -- "$BASE_DIR/../ffmpeg/artifacts/ffmpeg-${FFMPEG_VERSION}-macos-${ARCH}/opt/ffmpeg")

: ${FFMPEG_DIR:?}

if [ ! -e "$CHROMAPRINT_TARBALL" ]; then
  curl -s -L -O "$CHROMAPRINT_TARBALL_URL"
fi

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar xf "$BASE_DIR/$CHROMAPRINT_TARBALL" --strip-components=1

CHROMAPRINT_CMAKE_ARGS+=(
  -DCMAKE_CXX_FLAGS="-stdlib=libc++"
)

case "$ARCH" in
  arm64)
    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_OSX_ARCHITECTURES="arm64"
      -DCMAKE_OSX_DEPLOYMENT_TARGET="13.0"
    )
    ;;
  x64)
    CHROMAPRINT_CMAKE_ARGS+=(
      -DCMAKE_OSX_ARCHITECTURES="x86_64"
      -DCMAKE_OSX_DEPLOYMENT_TARGET="10.13"
    )
    ;;
  *)
    echo "Unknown architecture: $ARCH"
    exit 1
    ;;
esac

cmake "${CHROMAPRINT_CMAKE_ARGS[@]}" .

make -j$(nproc) V=1
make DESTDIR="$BASE_DIR/artifacts" install/strip
