#!/bin/bash
set -e

BUILD_DIR=".build/smoke"
TEST_BIN="${BUILD_DIR}/SystemLayoutSmokeTest"

mkdir -p "${BUILD_DIR}"

swiftc \
    Sources/KeyboardConverter.swift \
    Scripts/smoke-system-layouts.swift \
    -o "${TEST_BIN}" \
    -framework Carbon

"${TEST_BIN}"
