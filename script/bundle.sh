#!/usr/bin/env bash

set -eou pipefail

bundle package

# Touch the lockfile so timestamps are up-to-date. This causes
# inconsistencies for make tasks that depend on Gemfile.lock
touch "${BUNDLE_GEMFILE}.lock"
