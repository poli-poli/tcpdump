#!/bin/sh
set -e

# Фаззинг BPF

export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_EXIT_TIME=30

export ASAN_OPTIONS="halt_on_error=1:abort_on_error=1:symbolize=0:detect_odr_violation=1:log_path=/var/log/asan_bpf/fail:detect_stack_use_after_return=1:detect_leaks=1:use_unaligned=1:report_objects=1"
export LSAN_OPTIONS="detect_leaks=1:use_unaligned=1:report_objects=1:symbolize=0"
export UBSAN_OPTIONS="halt_on_error=1:abort_on_error=1:print_stacktrace=1:allocator_may_retun_null=1:log_path=/var/log/ubsan_bpf/fail"

TCPDUMP=/tcpdump/tcpdump-fuzz
BPF_CORPUS=/fuzz/bpf_corpus
BPF_OUT=/fuzz/bpf_output
JOBS=${AFL_JOBS:-4}

mkdir -p "$BPF_OUT" /var/log/asan_bpf /var/log/ubsan_bpf

echo "BPF fuzzing"
echo "binary: $TCPDUMP"
echo "corpus: $BPF_CORPUS"
echo "output: $BPF_OUT"
echo "num workers: $JOBS"
echo "AFL_EXIT_TIME: ${AFL_EXIT_TIME}s"

# Запускаем каждый фаззер в отдельном screen
for i in $(seq 0 $((JOBS - 1))); do
    if [ "$i" -eq 0 ]; then
        echo "bpf_${i} start master"
        screen -dm -S "bpf_${i}" timeout 600 afl-fuzz -i "$BPF_CORPUS" -o "$BPF_OUT" -M "bpf_${i}" -- "$TCPDUMP" -d -y EN10MB -F @@ 2>/dev/null
    else
        echo "bpf_${i} start slave"
        screen -dm -S "bpf_${i}" timeout 600 afl-fuzz -i "$BPF_CORPUS" -o "$BPF_OUT" -S "bpf_${i}" -- "$TCPDUMP" -d -y EN10MB -F @@ 2>/dev/null
    fi
done

echo "$JOBS fuzzers launched"

# Ожидание завершения фаззинга
while screen -ls | grep -q "bpf_"; do sleep 2; done

# Вывод статистики
echo "afl-whatsup $BPF_OUT"
afl-whatsup "$BPF_OUT" || true

# Сбор покрытия
mkdir -p /fuzz/bpf_coverage

# Собрать весь входной корпус в один
mkdir -p /fuzz/bpf-merged-corpus
for i in $(seq 0 $((JOBS - 1))); do
    QUEUE_DIR="${BPF_OUT}/bpf_${i}/queue"
    if [ -d "$QUEUE_DIR" ]; then
        cp "$QUEUE_DIR"/* /fuzz/bpf-merged-corpus/ 2>/dev/null || true
    fi
done

# Сбор покрытия (запуск входных данных через инструментированный бинарник)
TCPDUMP_COV=/tcpdump/tcpdump-fuzz
export LLVM_PROFILE_FILE="/fuzz/bpf_coverage/bpf-fuzz-%m.profraw"
for f in /fuzz/bpf-merged-corpus/*; do
    [ -f "$f" ] && "$TCPDUMP_COV" -d -y EN10MB -F "$f" || true
done

if ls /fuzz/bpf_coverage/*.profraw 1>/dev/null 2>&1; then
    /usr/lib/llvm-20/bin/llvm-profdata merge /fuzz/bpf_coverage/*.profraw -o /fuzz/bpf_coverage/merged.profdata
    /usr/lib/llvm-20/bin/llvm-cov report -instr-profile=/fuzz/bpf_coverage/merged.profdata "$TCPDUMP_COV"
    /usr/lib/llvm-20/bin/llvm-cov show -format=html -instr-profile=/fuzz/bpf_coverage/merged.profdata "$TCPDUMP_COV" > /fuzz/bpf_coverage/bpf-coverage-report.html
    echo "HTML report: /fuzz/bpf_coverage/bpf-coverage-report.html"
else
    echo "No .profraw files found"
fi