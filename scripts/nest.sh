#!/bin/bash
set -euo pipefail

NEST_VERSION="0.7.1"
NEST_SHA256="277510676c6229db98a3522b9cac312b1596fe469d54cbbcbe60caa83e6931b4"
NEST_HOME="$HOME/.nest"
NEST_BIN="$NEST_HOME/bin/nest"

install_nest() {
    local archive_url download_dir archive target_dir temporary_binary
    archive_url="https://github.com/mtj0928/nest/releases/download/${NEST_VERSION}/nest-macos.artifactbundle.zip"
    download_dir="$(mktemp -d)"
    archive="$download_dir/nest-macos.artifactbundle.zip"
    trap 'rm -rf "$download_dir"' EXIT

    curl -fsSL "$archive_url" -o "$archive"
    echo "${NEST_SHA256}  ${archive}" | shasum -a 256 -c -
    unzip -qo "$archive" -d "$download_dir"

    target_dir="$NEST_HOME/artifacts/mtj0928_nest_github.com_https/${NEST_VERSION}/nest-macos"
    temporary_binary="$target_dir/nest.tmp.$$"
    mkdir -p "$target_dir" "$NEST_HOME/bin"
    cp "$download_dir/nest.artifactbundle/nest-${NEST_VERSION}-macos/bin/nest" "$temporary_binary"
    chmod +x "$temporary_binary"
    mv -f "$temporary_binary" "$target_dir/nest"
    ln -sfn "$target_dir/nest" "$NEST_BIN"

    rm -rf "$download_dir"
    trap - EXIT
}

if [ ! -x "$NEST_BIN" ]; then
    install_nest
fi

"$NEST_BIN" "$@"
