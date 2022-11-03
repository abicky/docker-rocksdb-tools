FROM debian:bullseye as builder

# cf. https://github.com/facebook/rocksdb/blob/master/INSTALL.md
RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  ca-certificates \
  curl \
  libgflags-dev \
  libbz2-dev \
  liblz4-dev \
  libsnappy-dev \
  libzstd-dev \
  zlib1g-dev

ARG ROCKSDB_VERSION=7.1.2

RUN mkdir /build \
  && curl -sSL https://github.com/facebook/rocksdb/archive/refs/tags/v${ROCKSDB_VERSION}.tar.gz \
   | tar zxC /build --strip-component 1 \
  && cd /build \
  && DEBUG_LEVEL=0 LIB_MODE=shared PORTABLE=1 make -j$(nproc) tools

RUN mkdir -p /rocksdb/bin /rocksdb/lib \
  && cd /build \
  # cf. https://www.cmcrossroads.com/article/printing-value-makefile-variable
  && echo 'print-%:\n\t@echo $($*)' >>Makefile \
  && tools=$(make print-TOOLS | tail -1 | sed 's/ \+/\n/g' | sort -u) \
  && mv $tools /rocksdb/bin/ \
  && mv librocksdb.so* librocksdb_tools.so /rocksdb/lib \
  && strip /rocksdb/lib/* /rocksdb/bin/*

FROM scratch AS base-amd64

ARG ARCH=x86_64
COPY --from=builder /lib64/ld-linux-* /lib64/

FROM scratch AS base-arm64

ARG ARCH=aarch64
COPY --from=builder /lib/ld-linux-* /lib/

FROM base-$TARGETARCH
COPY --from=builder \
  /rocksdb/bin/ \
  /usr/local/bin/
COPY --from=builder \
  /lib/${ARCH}-linux-gnu/libbz2.so.1.0 \
  /lib/${ARCH}-linux-gnu/libc.so.6 \
  /lib/${ARCH}-linux-gnu/libdl.so.2 \
  /lib/${ARCH}-linux-gnu/libgcc_s.so.1 \
  /lib/${ARCH}-linux-gnu/libm.so.6 \
  /lib/${ARCH}-linux-gnu/libpthread.so.0 \
  /lib/${ARCH}-linux-gnu/librt.so.1 \
  /lib/${ARCH}-linux-gnu/libz.so.1 \
  /lib/${ARCH}-linux-gnu/
COPY --from=builder \
  /rocksdb/lib/ \
  /usr/lib/${ARCH}-linux-gnu/libgflags.so.2.2 \
  /usr/lib/${ARCH}-linux-gnu/liblz4.so.1 \
  /usr/lib/${ARCH}-linux-gnu/libsnappy.so.1 \
  /usr/lib/${ARCH}-linux-gnu/libstdc++.so.6 \
  /usr/lib/${ARCH}-linux-gnu/libzstd.so.1 \
  /usr/lib/${ARCH}-linux-gnu/
