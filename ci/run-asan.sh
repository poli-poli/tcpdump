#!/bin/sh
set -e

# Запустить тесты с ASAN и вывести логи санитайзера

echo "Testing with ASAN"

TCPDUMP=/tcpdump/tcpdump-asan
if [ ! -x "$TCPDUMP" ]; then
    echo "ASAN binary not found at $TCPDUMP"
    exit 1
fi

mkdir -p /var/log/asan
export TCPDUMP_BIN=/tcpdump/tcpdump-asan
ln -sf /tcpdump/config.h /tcpdump/tests/config.h
cd /tcpdump/tests && ./TESTrun
echo "ASAN findings"
{ cat /var/log/asan/* || echo "(no ASAN errors)"; }