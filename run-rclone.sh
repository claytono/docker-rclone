#!/bin/bash -eu

set -o pipefail

cp ~/.config/rclone/rclone.conf /tmp
./rclone-wrapper.rb --config /tmp/rclone.conf "$@"

