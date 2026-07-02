#!/bin/bash
set -e

# Фаззинг протоколов (кол-во протоколов=кол-во воркеров)

export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_EXIT_TIME=${AFL_EXIT_TIME:-30}

export ASAN_OPTIONS="halt_on_error=1:abort_on_error=1:symbolize=0:detect_odr_violation=1:log_path=/var/log/asan_dist/fail:detect_stack_use_after_return=1:detect_leaks=1:use_unaligned=1:report_objects=1"
export LSAN_OPTIONS="detect_leaks=1:use_unaligned=1:report_objects=1:symbolize=0"
export UBSAN_OPTIONS="halt_on_error=1:abort_on_error=1:print_stacktrace=1:allocator_may_retun_null=1:log_path=/var/log/ubsan_dist/fail"

TCPDUMP="/tcpdump/tcpdump-fuzz"
PCAP_CORPUS="/fuzz/pcap_corpus"
DIST_OUT="/fuzz/dist_output"

mkdir -p "$DIST_OUT" /var/log/asan_dist /var/log/ubsan_dist

PROTOCOLS=("snmp" "radius" "rpc" "rtp" "tftp" "vxlan")
JOBS=${#PROTOCOLS[@]}

echo "Protocol fuzzing"
echo "binary: $TCPDUMP"
echo "corpus: $PCAP_CORPUS"
echo "num workers: $JOBS"
echo "AFL_EXIT_TIME: ${AFL_EXIT_TIME}s"

for i in "${!PROTOCOLS[@]}"; do
    PROTO="${PROTOCOLS[$i]}"
    OUT_DIR="${DIST_OUT}/out_${PROTO}"
    mkdir -p "$OUT_DIR"

    if [ "$i" -eq 0 ]; then
        echo "Запуск мастера для $PROTO"
        screen -dm -S "fuzz_${PROTO}" timeout 600 afl-fuzz -i "$PCAP_CORPUS" -o "$OUT_DIR" -M "master_${PROTO}" -- "$TCPDUMP" -n -r @@ -T "$PROTO"
    else
        echo "Запуск слейва для $PROTO"
        screen -dm -S "fuzz_${PROTO}" timeout 600 afl-fuzz -i "$PCAP_CORPUS" -o "$OUT_DIR" -S "slave_${PROTO}" -- "$TCPDUMP" -n -r @@ -T "$PROTO"
    fi
done

# Ожидание завершения фаззинга
while screen -ls | grep -q "fuzz_"; do sleep 2; done

# Вывод статистики
for PROTO in "${PROTOCOLS[@]}"; do
    OUT_DIR="${DIST_OUT}/out_${PROTO}"
    echo "afl-whatsup: $PROTO"
    if [ -d "$OUT_DIR" ]; then
        afl-whatsup "$OUT_DIR" || true
    fi
done

# Сбор покрытия
mkdir -p /fuzz/dist_coverage

TCPDUMP_COV=/tcpdump/tcpdump-fuzz
export LLVM_PROFILE_FILE="/fuzz/dist_coverage/dist-fuzz-%m.profraw"

   # Собрать весь входной корпус в один
mkdir -p /fuzz/dist-merged-corpus
for PROTO in "${PROTOCOLS[@]}"; do
    OUT_DIR="${DIST_OUT}/out_${PROTO}"
    for INSTANCE_TYPE in "master_${PROTO}" "slave_${PROTO}"; do
        QUEUE_DIR="${OUT_DIR}/${INSTANCE_TYPE}/queue"
        if [ -d "$QUEUE_DIR" ]; then
            cp "$QUEUE_DIR"/* /fuzz/dist-merged-corpus/ || true
        fi
    done
done

for f in /fuzz/dist-merged-corpus/*; do
    [ -f "$f" ] && "$TCPDUMP_COV" -n -r "$f" || true
done

if ls /fuzz/dist_coverage/*.profraw 1>/dev/null 2>&1; then
    /usr/lib/llvm-20/bin/llvm-profdata merge /fuzz/dist_coverage/*.profraw -o /fuzz/dist_coverage/merged.profdata
    /usr/lib/llvm-20/bin/llvm-cov report -instr-profile=/fuzz/dist_coverage/merged.profdata "$TCPDUMP_COV"
    /usr/lib/llvm-20/bin/llvm-cov show -format=html -instr-profile=/fuzz/dist_coverage/merged.profdata "$TCPDUMP_COV" > /fuzz/dist_coverage/dist-coverage-report.html
    echo "HTML report: /fuzz/dist_coverage/dist-coverage-report.html"
else
    echo "No .profraw files found"
fi