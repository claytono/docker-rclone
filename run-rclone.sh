#!/bin/bash -eu

set -o pipefail

rclone "$@" 2>&1 \
    | tee log \
    | "$(dirname "$BASH_SOURCE")"/rclone-report.rb

