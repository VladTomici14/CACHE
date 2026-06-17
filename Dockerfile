FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Ubuntu 20.04 ships iverilog 10.x which lacks full SystemVerilog support.
# Build iverilog v12 from source for -g2012 compatibility.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
        autoconf \
        gperf \
        flex \
        bison \
        curl \
        make \
        python3 && \
    curl -fsSL https://github.com/steveicarus/iverilog/archive/refs/tags/v12_0.tar.gz \
        -o /tmp/iverilog.tar.gz && \
    tar xzf /tmp/iverilog.tar.gz -C /tmp && \
    cd /tmp/iverilog-12_0 && \
    sh autoconf.sh && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    cd / && rm -rf /tmp/iverilog-12_0 /tmp/iverilog.tar.gz && \
    apt-get purge -y build-essential autoconf gperf flex bison curl && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY . .

RUN make data && make all

CMD ["make", "all"]
