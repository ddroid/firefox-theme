#!/usr/bin/env bash

# Delegate to root install.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../install.sh" "$@"
