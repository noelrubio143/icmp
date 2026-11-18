#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
API="${API:-24}"

NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
[ -d "$NDK" ] || { echo "NDK not found"; exit 1; }
BIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

cd "$SRC"
go mod download || true

build_android () {
  local abi="$1" goarch="$2" cc="$3" goarm="${4:-}"
  mkdir -p "$OUT/jniLibs/$abi"
  echo ">>> $abi"
  CGO_ENABLED=1 GOOS=android GOARCH="$goarch" GOARM="$goarm" CC="$BIN/$cc" \
    go build -trimpath -buildmode=pie -ldflags "-s -w" \
    -o "$OUT/jniLibs/$abi/libpingtunnel.so" .
}

build_android arm64-v8a   arm64 aarch64-linux-android${API}-clang
build_android armeabi-v7a arm   armv7a-linux-androideabi${API}-clang 7

mkdir -p "$OUT/server"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "$OUT/server/pingtunnel-linux-amd64" .
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o "$OUT/server/pingtunnel-linux-arm64" .
