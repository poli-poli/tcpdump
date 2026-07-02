#!/bin/sh
set -e

# Запустить тесты с UBSAN и вывести логи санитайзера

echo "Testing with UBSAN"

TCPDUMP=/tcpdump/tcpdump-ubsan
if [ ! -x "$TCPDUMP" ]; then
    echo "UBSAN binary not found at $TCPDUMP"
    exit 1
fi

mkdir -p /var/log/ubsan
export TCPDUMP_BIN=/tcpdump/tcpdump-ubsan
ln -sf /tcpdump/config.h /tcpdump/tests/config.h
cd /tcpdump/tests && ./TESTrun
echo "UBSAN findings"
{ cat /var/log/ubsan/* || echo "(no UBSAN findings)"; }
