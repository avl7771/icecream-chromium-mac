#!/bin/sh

realpath() {
  python -c "import os; print(os.path.realpath('$1'))"
}

ICECC_CREATE_ENV="${ICECC_CREATE_ENV:-$(which icecc-create-env)}"
ICECC_ENV_DIR="${ICECC_ENV_DIR:-$HOME/.icecc-envs}"
SCRIPT_DIR="$(realpath $(dirname $0))"
ICECC_CREATE_ENV_LINUX="${ICECC_CREATE_ENV_LINUX:-$SCRIPT_DIR/create-icecc-env-linux.py}"
ICECC_LINUX_ENV_DIR="${ICECC_ENV_DIR}/linux"

mkdir -p $ICECC_LINUX_ENV_DIR
if [ ! -w $ICECC_ENV_DIR ]; then
  echo "Error: Can't write to $ICECC_ENV_DIR. Set \$ICECC_ENV_DIR to change." >&2
  exit 1
fi

if [ ! -x $ICECC_CREATE_ENV ]; then
  echo "Error: Can't execute $ICECC_CREATE_ENV. Set \$ICECC_CREATE_ENV to change." >&2
  exit 1
fi

CHROMIUM_PATH="$(realpath ${1:-$CHROMIUM_PATH})"

if [ -z "$CHROMIUM_PATH" ]; then
  echo "Usage: $0 [path-to-chromium]" >&2
  exit 1
fi

CLANG_VERSION_SCRIPT="${CHROMIUM_PATH}/tools/clang/scripts/update.py"

if [ ! -x "$CLANG_VERSION_SCRIPT" ]; then
  echo "Error: No clang version script found at $CLANG_VERSION_SCRIPT." >&2
  exit 1
fi

CLANG_VERSION=`$CLANG_VERSION_SCRIPT --print-revision`

if [ -z "$CLANG_VERSION" ]; then
  echo "Error: Couldn't determine version using $CLANG_VERSION_SCRIPT." >&2
  exit 1
fi

IPADDRESS=`route -v get default | tail -n 1 | awk '{print $NF}'`
ENV_NAME="clang-${CLANG_VERSION}-${IPADDRESS}.tar.gz"
MAC_ENV_PATH="${ICECC_ENV_DIR}/${ENV_NAME}"
LINUX_ENV_PATH="${ICECC_LINUX_ENV_DIR}/${ENV_NAME}"

if [ ! -e "$MAC_ENV_PATH" ]; then
  LLVM_PATH="${CHROMIUM_PATH}/third_party/llvm-build/Release+Asserts"
  CLANG_PATH="${LLVM_PATH}/bin/clang"
  PLUGINS_PATH="${LLVM_PATH}/lib"

  if [ ! -x "$CLANG_PATH" ]; then
    echo "Error: Can't find clang executable at $CLANG_PATH." >&2
    exit 1
  fi

  # As of https://chromium-review.googlesource.com/c/1387395, plugins are built into clang.
  # TODO: Remove ADD_PLUGINS altogether when support for Chromium older than
  # that change is no longer needed.
  ADD_PLUGINS=""
  if [ -e "$PLUGINS_PATH/libFindBadConstructs.dylib" ]; then
    ADD_PLUGINS="--addfile $PLUGINS_PATH/libFindBadConstructs.dylib --addfile $PLUGINS_PATH/libBlinkGCPlugin.dylib"
  fi

  TEMP_ENV_FILENAME=`(cd $ICECC_ENV_DIR && exec 5>&1 && $ICECC_CREATE_ENV --clang $CLANG_PATH \
                      $ADD_PLUGINS 1>/dev/null)`
  if [ -z "$TEMP_ENV_FILENAME" ]; then
    echo "Error: couldn't get file name of generated file." >&2
    exit 1
  fi

  TEMP_ENV_PATH=${ICECC_ENV_DIR}/${TEMP_ENV_FILENAME}
  if [ ! -e "$TEMP_ENV_PATH" ]; then
    echo "Error: Can't find environment created at $TEMP_ENV_PATH." >&2
    exit 1
  fi

  mv "$TEMP_ENV_PATH" "$MAC_ENV_PATH"
fi

if [ ! -x "$ICECC_CREATE_ENV_LINUX" ]; then
  echo "Warning: Can't execute $ICECC_CREATE_ENV_LINUX." >&2
  echo "Cross-compilation on linux not available." >&2
  LINUX_ENV_PATH=""
elif [ ! -e "$LINUX_ENV_PATH" ]; then
  SCRIPT_DIR_LINUX=$(dirname "${ICECC_CREATE_ENV_LINUX}")
  ICECC_BASE_LINUX="${SCRIPT_DIR_LINUX}/clang-icecc-base-linux.tar.gz"
  TEMP_ENV_FILENAME=`(cd $ICECC_LINUX_ENV_DIR && $ICECC_CREATE_ENV_LINUX $ICECC_BASE_LINUX $CLANG_VERSION $IPADDRESS)`
fi

UNAME_S=`uname -s`
UNAME_R=`uname -r | sed -E 's/(\.[0-9]+)*//g'`
UNAME_M=`uname -m`
ICECC_VERSION="${UNAME_S}${UNAME_R}_${UNAME_M}:${MAC_ENV_PATH}"

if [ "$LINUX_ENV_PATH" != "" ]; then
  ICECC_VERSION="${ICECC_VERSION},${UNAME_M}:${LINUX_ENV_PATH}"
fi

echo $ICECC_VERSION
