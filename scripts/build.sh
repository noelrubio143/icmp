#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
API="${API:-24}"

NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
[ -d "$NDK" ] || { echo "NDK not found"; exit 1; }
BIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

cd "$SRC"

# find the directory that contains package main
MAINDIR=""
for d in cmd . ; do
  if [ -d "$d" ] && grep -lq '^package main' "$d"/*.go 2>/dev/null; then MAINDIR="$d"; break; fi
done
if [ -z "$MAINDIR" ]; then
  MAINDIR="$(grep -rl '^package main' --include=*.go . | head -1 | xargs -r dirname)"
fi
[ -n "$MAINDIR" ] || { echo "no package main found"; ls -R . | head -50; exit 1; }
echo "main package dir: $MAINDIR"
PKG="./${MAINDIR#./}"

go mod download || true

build_android () {
  local abi="$1" goarch="$2" cc="$3" goarm="${4:-}"
  mkdir -p "$OUT/jniLibs/$abi"
  echo ">>> $abi"
  CGO_ENABLED=1 GOOS=android GOARCH="$goarch" GOARM="$goarm" CC="$BIN/$cc" \
    go build -trimpath -buildmode=pie -ldflags "-s -w" \
    -o "$OUT/jniLibs/$abi/libpingtunnel.so" "$PKG"
}

build_android arm64-v8a   arm64 aarch64-linux-android${API}-clang
build_android armeabi-v7a arm   armv7a-linux-androideabi${API}-clang 7

mkdir -p "$OUT/server"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "$OUT/server/pingtunnel-linux-amd64" "$PKG"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o "$OUT/server/pingtunnel-linux-arm64" "$PKG"

# sanity check: must be real executables, not archives
for f in "$OUT"/jniLibs/*/libpingtunnel.so "$OUT"/server/*; do
  if head -c 7 "$f" | grep -q '!<arch>'; then
    echo "ERROR: $f is an archive, not an executable"; exit 1
  fi
done
echo "OK"
