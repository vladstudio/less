#!/bin/bash
set -e
cd "$(dirname "$0")"
source ../scripts/build-kit.sh
build_app "Less" --info Less/Info.plist
