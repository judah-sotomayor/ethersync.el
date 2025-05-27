#!/usr/bin/env bash

set -Eeuo pipefail

printf "Check conventional commits:\n"
cog check
