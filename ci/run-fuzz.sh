#!/bin/sh
set -e

# Фаззинг с санитазерами и сбором покрытия

export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_EXIT_TIME=30

export ASAN_OPTIONS="halt_on_error=1:abort_on_error=1:symbolize=0:detect_odr_violation=1:log_path=/var/log/asan_fuzz/fail:detect_stack_use_after_return=1:detect_leaks=1:use_unaligned=1:report_objects=1"
export LSAN_OPTIONS="detect_leaks=1:use_unaligned=1:report_objects=1:symbolize=0"
export UBSAN_OPTIONS="halt_on_error=1:abort_on_error=1:print_stacktrace=1:allocator_may_retun_null=1:log_path=/var/log/ubsan_fuzz/fail"

TCPDUMP=/tcpdump/tcpdump-fuzz
CORPUS=/fuzz/corpus
OUT=/fuzz/output
JOBS=4

mkdir -p "$CORPUS" "$OUT" /var/log/asan_fuzz /var/log/ubsan_fuzz

# Копируем .pcap из тестов во входную директорию
if [ -z "$(ls -A "$CORPUS")" ]; then
    cp /tcpdump/tests/*.pcap "$CORPUS/" || true
fi

echo "fuzzing"
echo "binary: $TCPDUMP"
echo "input directory: $CORPUS"
echo "num workers: $JOBS"
echo "AFL_EXIT_TIME: ${AFL_EXIT_TIME}s"

# Запуск фаззинга
for i in $(seq 0 $((JOBS - 1))); do
    DIR="${OUT}/fuzzer_${i}"
    mkdir -p "$DIR"
    if [ "$i" -eq 0 ]; then
        echo "fuzzer_${i} start master"
        screen -dm -S "fuzzer_${i}" timeout 600 afl-fuzz -i "$CORPUS" -o "$DIR" -M "fuzzer_${i}" -- "$TCPDUMP" -n -r @@
    else
        echo "fuzzer_${i} start slave"
        screen -dm -S "fuzzer_${i}" timeout 600 afl-fuzz -i "$CORPUS" -o "$DIR" -S "fuzzer_${i}" -- "$TCPDUMP" -n -r @@
    fi
done

# Ожидание завершения фаззинга
while screen -ls | grep -q "fuzzer_"; do sleep 2; done

# Сбор статистики
for i in $(seq 0 $((JOBS - 1))); do
    FUZZER_DIR="${OUT}/fuzzer_${i}/fuzzer_${i}"
    if [ -d "$FUZZER_DIR" ]; then
        echo ""
        echo "--- afl-whatsup fuzzer_${i} ---"
        afl-whatsup "$FUZZER_DIR" || true
    fi
done

# Сбор покрытия
mkdir -p /fuzz/coverage

# Собрать весь входной корпус в один
mkdir -p /fuzz/merged-corpus
for i in $(seq 0 $((JOBS - 1))); do
    QUEUE_DIR="${OUT}/fuzzer_${i}/fuzzer_${i}/queue"
    if [ -d "$QUEUE_DIR" ]; then
        cp "$QUEUE_DIR"/* /fuzz/merged-corpus/ || true
    fi
done

TCPDUMP_COV=/tcpdump/tcpdump-fuzz
if [ -x "$TCPDUMP_COV" ]; then
    export LLVM_PROFILE_FILE="/fuzz/coverage/tcpdump-fuzz-%m.profraw"
    for f in /fuzz/merged-corpus/*; do
        [ -f "$f" ] && "$TCPDUMP_COV" -n -r "$f" || true
    done

    if ls /fuzz/coverage/*.profraw 1>/dev/null 2>&1; then
        /usr/lib/llvm-20/bin/llvm-profdata merge /fuzz/coverage/*.profraw -o /fuzz/coverage/merged.profdata
        /usr/lib/llvm-20/bin/llvm-cov report -instr-profile=/fuzz/coverage/merged.profdata "$TCPDUMP_COV"
        /usr/lib/llvm-20/bin/llvm-cov show -format=html -instr-profile=/fuzz/coverage/merged.profdata "$TCPDUMP_COV" > /fuzz/coverage/fuzz-coverage-report.html
        echo "HTML report /fuzz/coverage/fuzz-coverage-report.html"
    else
        echo "No .profraw files found"
    fi
else
    echo "Coverage binary not found"
fi
