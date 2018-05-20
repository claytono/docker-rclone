#!/bin/bash -eu

# This only wrapper only exists for backwards compatibility and
# rclone-wrapper.rb should be used directly for anything new.
set -o pipefail

./rclone-wrapper.rb "$@" 2>&1 \
    | tee log \

