#!/bin/sh
set -e

# Запуск функциональных тестов

TCPDUMP=/tcpdump/tcpdump-normal
if [ ! -x "$TCPDUMP" ]; then
    echo "Binary not found at $TCPDUMP"
    exit 1
fi

export TCPDUMP_BIN=/tcpdump/tcpdump-normal
ln -sf /tcpdump/config.h /tcpdump/tests/config.h
cd /tcpdump/tests && ./TESTrun
PASSED=$(cat .passed 2>/dev/null)
FAILED=$(cat .failed 2>/dev/null)
echo "Passed: $PASSED"
echo "Failed: $FAILED"
