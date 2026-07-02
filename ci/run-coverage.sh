#!/bin/sh
set -e

# Сбор покрытия по тестам

TCPDUMP_COV=/tcpdump/tcpdump-coverage
COVERAGE_DIR=/coverage

mkdir -p "$COVERAGE_DIR"

# Проверяем что coverage-бинарник существует
if [ ! -x "$TCPDUMP_COV" ]; then
    echo "Coverage binary not found at $TCPDUMP_COV"
    exit 1
fi

# Очищаем старые профили
rm -f "$COVERAGE_DIR"/*.profraw

# Запускаем тесты
export LLVM_PROFILE_FILE="$COVERAGE_DIR/tcpdump-%m.profraw"
export TCPDUMP_BIN=/tcpdump/tcpdump-coverage
ln -sf /tcpdump/config.h /tcpdump/tests/config.h
echo "Running test"
cd /tcpdump/tests && ./TESTrun
cd /tcpdump

echo "Merging profile data"
/usr/lib/llvm-20/bin/llvm-profdata merge "$COVERAGE_DIR"/*.profraw -o "$COVERAGE_DIR/merged.profdata"
/usr/lib/llvm-20/bin/llvm-cov report -instr-profile="$COVERAGE_DIR/merged.profdata" "$TCPDUMP_COV"
/usr/lib/llvm-20/bin/llvm-cov show -format=html -instr-profile="$COVERAGE_DIR/merged.profdata" "$TCPDUMP_COV" > "$COVERAGE_DIR/coverage-report.html"

echo "HTML report $COVERAGE_DIR/coverage-report.html"