# Из корня проекта:
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=normal -t tcpdump-ci:normal .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=coverage -t tcpdump-ci:coverage .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=asan -t tcpdump-ci:asan .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=ubsan -t tcpdump-ci:ubsan .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=fuzz -t tcpdump-ci:fuzz .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=fuzz-bpf -t tcpdump-ci:fuzz-bpf .
#   docker build -f ci/Dockerfile --build-arg BUILD_TYPE=fuzz-distributed -t tcpdump-ci:fuzz-distributed .

FROM aflplusplus/aflplusplus:latest
ARG BUILD_TYPE=normal
# Очистить кэш
RUN apt-get clean && rm -rf /var/lib/apt/lists/* && apt-get clean

RUN apt-get update && apt-get install -y wget make perl screen python3

# OpenSSL 1.0.2 совместимый со старым tcpdump
RUN wget -q https://github.com/openssl/openssl/releases/download/OpenSSL_1_0_2u/openssl-1.0.2u.tar.gz && \
    tar xzf openssl-1.0.2u.tar.gz && cd openssl-1.0.2u && ./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared && \
    make -j$(nproc) && make install && echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl.conf && \
    ldconfig && cd / && rm -rf openssl-1.0.2u*

# Собрать libpcap с инструментацией
RUN wget http://www.tcpdump.org/release/libpcap-1.5.3.tar.gz && tar -xzvf libpcap-1.5.3.tar.gz

# Сборка libpcap для разных типов
RUN if [ "$BUILD_TYPE" = "normal" ]; then \
        cd libpcap-1.5.3 && ./configure && make -j$(nproc) && make install; \
    elif [ "$BUILD_TYPE" = "coverage" ]; then \
        cd libpcap-1.5.3 && CC=clang ./configure CFLAGS="-fprofile-instr-generate -fcoverage-mapping -g -O0" && \
        make -j$(nproc) && make install; \
    elif [ "$BUILD_TYPE" = "asan" ]; then \
        cd libpcap-1.5.3 && CC=clang ./configure CFLAGS="-fsanitize=address -g -O1" && \
        make -j$(nproc) && make install; \
    elif [ "$BUILD_TYPE" = "ubsan" ]; then \
        cd libpcap-1.5.3 && CC=clang ./configure CFLAGS="-fsanitize=undefined -g -O1" && \
        make -j$(nproc) && make install; \
    elif [ "$BUILD_TYPE" = "fuzz" ] || [ "$BUILD_TYPE" = "fuzz-bpf" ] || [ "$BUILD_TYPE" = "fuzz-distributed" ]; then \
        cd libpcap-1.5.3 && AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-clang-fast ./configure \
            CFLAGS="-g -O0 -fprofile-instr-generate -fcoverage-mapping" \
            LDFLAGS="-fsanitize=address -fsanitize=undefined" && \
        make -j$(nproc) && make install; \
    else echo "Unknown BUILD_TYPE: $BUILD_TYPE" && exit 1; \
    fi

WORKDIR /tcpdump

COPY . .
COPY ci/ /ci/

# Отключаем упавшие тесты
RUN /ci/disable_tests.sh

# Генерируем ./configure из configure.ac
RUN ./autogen.sh

# Релиз сборка
RUN if [ "$BUILD_TYPE" = "normal" ]; then \
        CC=clang ./configure --prefix=/usr --with-crypto=/usr/local/ssl \
            CFLAGS="-Wno-implicit-int" CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib -Wl,-rpath,/usr/local/ssl/lib" && \
        make clean && make && \
        cp tcpdump /tcpdump/tcpdump-normal; \
    fi

# Сборка для сбора покрытия
RUN if [ "$BUILD_TYPE" = "coverage" ]; then \
        CC=clang ./configure \
            CFLAGS="-fprofile-instr-generate -fcoverage-mapping -g -O0 -Wno-implicit-int" \
            CPPFLAGS="-I/usr/local/ssl/include" \
            LDFLAGS="-L/usr/local/ssl/lib" && \
        make clean && make && \
        cp tcpdump /tcpdump/tcpdump-coverage; \
    fi

# ASAN сборка 
RUN if [ "$BUILD_TYPE" = "asan" ]; then \
        CC=clang ./configure \
            CFLAGS="-fsanitize=address -g -O1 -Wno-implicit-int" \
            CPPFLAGS="-I/usr/local/ssl/include" \
            LDFLAGS="-L/usr/local/ssl/lib -fsanitize=address" && \
        make clean && make && \
        cp tcpdump /tcpdump/tcpdump-asan; \
    fi

ENV ASAN_OPTIONS="halt_on_error=0:detect_odr_violation=1:log_path=/var/log/asan/fail:detect_stack_use_after_return=1:detect_leaks=1:use_unaligned=1:report_objects=1"
ENV LSAN_OPTIONS="detect_leaks=1:use_unaligned=1:report_objects=1"

# UBSAN сборка
RUN if [ "$BUILD_TYPE" = "ubsan" ]; then \
        CC=clang ./configure \
            CFLAGS="-fsanitize=undefined -g -O1 -Wno-implicit-int" \
            CPPFLAGS="-I/usr/local/ssl/include" \
            LDFLAGS="-L/usr/local/ssl/lib -fsanitize=undefined" && \
        make clean && make && \
        cp tcpdump /tcpdump/tcpdump-ubsan; \
    fi

ENV UBSAN_OPTIONS="log_path=/var/log/ubsan/fail:print_stacktrace=1:halt_on_error=0"

# Fuzz сборка с санитайзерами и покрытием
RUN if [ "$BUILD_TYPE" = "fuzz" ] || [ "$BUILD_TYPE" = "fuzz-bpf" ] || [ "$BUILD_TYPE" = "fuzz-distributed" ]; then \
        AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-clang-fast ./configure \
            --with-crypto=/usr/local/ssl \
            CFLAGS="-Wno-implicit-int -fprofile-instr-generate -fcoverage-mapping -g -O0" \
            CPPFLAGS="-I/usr/local/ssl/include" \
            LDFLAGS="-L/usr/local/ssl/lib -fsanitize=address -fsanitize=undefined" && \
        make clean && make && \
        cp tcpdump /tcpdump/tcpdump-fuzz; \
    fi

# Корпус для фаззинга на основе .pcap файлов из тестов
RUN if [ "$BUILD_TYPE" = "fuzz" ] || [ "$BUILD_TYPE" = "fuzz-distributed" ]; then \
        mkdir -p /fuzz/pcap_corpus && \
        cp tests/*.pcap /fuzz/pcap_corpus/ ; \
    fi

# Корпус для фаззинга BPF
RUN if [ "$BUILD_TYPE" = "fuzz-bpf" ]; then /ci/prepare-bpf-corpus.sh; fi

# Сохраняем BUILD_TYPE для ENTRYPOINT
RUN echo "$BUILD_TYPE" > /build_type
RUN cat /build_type

# ENTRYPOINT запускает соответствующий CI-скрипт
ENTRYPOINT ["/bin/sh", "-c", "exec /ci/run-$(cat /build_type).sh"]