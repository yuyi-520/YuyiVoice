#!/bin/bash
# ld64.lld 包装脚本（仅 Linux 构建用）
exec python3 "$(dirname "$0")/ldwrap.py" "$@"