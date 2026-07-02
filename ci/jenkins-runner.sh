#!/bin/bash
set -e

# Запуск ci Jenkins

REPO_URL="https://github.com/poli-poli/tcpdump.git"
BRANCH="tasks"
WORK_DIR="$(pwd)/workspace"
ARTIFACTS_DIR="$(pwd)/artifact"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Все доступные типы сборок
ALL_BUILD_TYPES=("normal" "coverage" "asan" "ubsan" "fuzz" "fuzz-bpf" "fuzz-distributed")

# Определяем какие сборки запускать
BUILD_TYPE="${BUILD_TYPE:-all}"

if [ "$BUILD_TYPE" = "all" ]; then
    BUILD_TYPES=("${ALL_BUILD_TYPES[@]}")
else
    IFS=',' read -ra BUILD_TYPES <<< "$BUILD_TYPE"
fi

echo "Запуск CI для ${BUILD_TYPES[*]}"

# Клонирование
rm -rf "$WORK_DIR" "$ARTIFACTS_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACTS_DIR"

git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

for bt in "${BUILD_TYPES[@]}"; do
    mkdir -p "$ARTIFACTS_DIR/$bt"
done

# Сборка Docker image
declare -A IMAGES
for bt in "${BUILD_TYPES[@]}"; do
    IMAGE_TAG="tcpdump-ci:${bt}-${TIMESTAMP}"
    echo "Сборка образа $IMAGE_TAG (BUILD_TYPE=$bt)"
    docker build --no-cache -f ci/Dockerfile --build-arg BUILD_TYPE="$bt" -t "$IMAGE_TAG" .
    IMAGES[$bt]="$IMAGE_TAG"
done

# Запуск контейнеров
run_normal() {
    echo "Release"
    docker run -v "$ARTIFACTS_DIR/normal:/output:rw" "${IMAGES[normal]}" /bin/sh -c "
            /ci/run-normal.sh || true "
}

run_coverage() {
    echo "Coverage"
    docker run -v "$ARTIFACTS_DIR/coverage:/output:rw" "${IMAGES[coverage]}" /bin/sh -c "
            /ci/run-coverage.sh || true
            cp -r /coverage/* /output/ || true "
}

run_asan() {
    echo "ASAN"
    docker run --rm \
        -v "$ARTIFACTS_DIR/asan:/output:rw" \
        "${IMAGES[asan]}" \
        /bin/sh -c "
            /ci/run-asan.sh || true
            cp -r /var/log/asan/* /output/ || true
        "
}

run_ubsan() {
    echo "UBSAN"
    docker run --rm \
        -v "$ARTIFACTS_DIR/ubsan:/output:rw" \
        "${IMAGES[ubsan]}" \
        /bin/sh -c "
            /ci/run-ubsan.sh || true
            cp -r /var/log/ubsan/* /output/ || true
        "
}

run_fuzz() {
    echo "Fuzzing"
    docker run --rm \
        -v "$ARTIFACTS_DIR/fuzz:/output:rw" \
        "${IMAGES[fuzz]}" \
        /bin/sh -c "
            /ci/run-fuzz.sh 2>&1 || true
            cp -r /fuzz/output/* /output/ || true
            mkdir -p /output/coverage
            cp -r /fuzz/coverage/* /output/coverage/ || true
            mkdir -p /output/merged-corpus
            cp -r /fuzz/merged-corpus/* /output/merged-corpus/ || true
            mkdir -p /output/sanitizers
            cp -r /var/log/asan_fuzz/* /output/sanitizers/ || true
            cp -r /var/log/ubsan_fuzz/* /output/sanitizers/ || true
        "
}

run_fuzz_bpf() {
    echo "Fuzzing bpf"
    docker run --rm \
        -v "$ARTIFACTS_DIR/fuzz-bpf:/output:rw" \
        "${IMAGES[fuzz-bpf]}" \
        /bin/sh -c "
            /ci/prepare-bpf-corpus.sh || true
            /ci/run-fuzz-bpf.sh 2>&1 || true
            cp -r /fuzz/bpf_output/* /output/ || true
            mkdir -p /output/coverage
            cp -r /fuzz/bpf_coverage/* /output/coverage/ || true
            mkdir -p /output/merged-corpus
            cp -r /fuzz/bpf-merged-corpus/* /output/merged-corpus/ || true
            mkdir -p /output/sanitizers
            cp -r /var/log/asan_bpf/* /output/sanitizers/ || true
            cp -r /var/log/ubsan_bpf/* /output/sanitizers/ || true
        "
}

run_fuzz_distributed() {
    echo "Fuzzing protocols"
    docker run --rm \
        -v "$ARTIFACTS_DIR/fuzz-distributed:/output:rw" \
        "${IMAGES[fuzz-distributed]}" \
        /bin/sh -c "
            /ci/run-fuzz-distributed.sh 2>&1 || true
            cp -r /fuzz/dist_output/* /output/ || true
            mkdir -p /output/coverage
            cp -r /fuzz/dist_coverage/* /output/coverage/ || true
            mkdir -p /output/merged-corpus
            cp -r /fuzz/dist-merged-corpus/* /output/merged-corpus/ || true
            mkdir -p /output/sanitizers
            cp -r /var/log/asan_dist/* /output/sanitizers/ || true
            cp -r /var/log/ubsan_dist/* /output/sanitizers/ || true
        "
}

# Запуск контейнеров
declare -A PIDS

for bt in "${BUILD_TYPES[@]}"; do
    case "$bt" in
        normal)
            run_normal &
            PIDS[normal]=$!
            ;;
        coverage)
            run_coverage &
            PIDS[coverage]=$!
            ;;
        asan)
            run_asan &
            PIDS[asan]=$!
            ;;
        ubsan)
            run_ubsan &
            PIDS[ubsan]=$!
            ;;
        fuzz)
            run_fuzz &
            PIDS[fuzz]=$!
            ;;
        fuzz-bpf)
            run_fuzz_bpf &
            PIDS[fuzz-bpf]=$!
            ;;
        fuzz-distributed)
            run_fuzz_distributed &
            PIDS[fuzz-distributed]=$!
            ;;
        *)
            echo "Unknown build type $bt"
            ;;
    esac
done

echo "Waititng for all builds to finist"
FAILED_BUILDS=()

for bt in "${BUILD_TYPES[@]}"; do
    if [ -n "${PIDS[$bt]:-}" ]; then
        echo "Ожидание $bt (PID: ${PIDS[$bt]})"
        if wait "${PIDS[$bt]}"; then
            echo "$bt успех"
        else
            echo "$bt упала"
            FAILED_BUILDS+=("$bt")
        fi
    fi
done

# Очистка образов
for bt in "${BUILD_TYPES[@]}"; do
    docker rmi "${IMAGES[$bt]}" || true
done

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo "Failed ${FAILED_BUILDS[*]}"
fi

# Возвращаем код ошибки
if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    exit 1
fi