FROM arthurch9102/bullseye-gcc16:latest
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# ==========================================
# 1. 编译现代高性能内存分配器：mimalloc
# ==========================================
RUN git clone --depth 1 --branch v3.5.0 https://github.com/microsoft/mimalloc.git /tmp/mimalloc && \
    cd /tmp/mimalloc && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DMI_BUILD_SHARED=ON -DMI_BUILD_STATIC=ON && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/mimalloc

# ==========================================
# 2. 编译高性能无锁并发队列：concurrentqueue
# ==========================================
RUN git clone --depth 1 --branch v1.0.5 https://github.com/cameron314/concurrentqueue.git /tmp/concurrentqueue && \
    cd /tmp/concurrentqueue && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local && \
    ninja install && \
    cd / && rm -rf /tmp/concurrentqueue

# ==========================================
# 3. 编译 Sentry 崩溃捕获 SDK (sentry-native)
# ==========================================
RUN git clone --depth 1 --branch 0.16.3 https://github.com/getsentry/sentry-native.git /tmp/sentry-native && \
    cd /tmp/sentry-native && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DSENTRY_BACKEND=crashpad && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/sentry-native

# ==========================================
# 4. 编译 WebRTC 核心：libdatachannel
# ==========================================
RUN git clone --depth 1 --branch v0.24.5 https://github.com/paullouisageneau/libdatachannel.git /tmp/libdatachannel && \
    cd /tmp/libdatachannel && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/libdatachannel

# ==========================================
# 5. 编译 NVIDIA 硬件编解码头文件 (nv-codec-headers)
# ==========================================
RUN git clone --depth 1 --branch n13.1.15.0 https://github.com/FFmpeg/nv-codec-headers.git /tmp/nv-codec-headers && \
    cd /tmp/nv-codec-headers && \
    make -j$(nproc) PREFIX=/usr/local && \
    make install PREFIX=/usr/local && \
    cd / && rm -rf /tmp/nv-codec-headers

# ==========================================
# 6. 编译 Intel oneVPL 硬件加速库 (libvpl)
# ==========================================
RUN git clone --depth 1 --branch v2.17.0 https://github.com/intel/libvpl.git /tmp/libvpl && \
    cd /tmp/libvpl && \
    cmake -B build -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTS=OFF && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    cd / && rm -rf /tmp/libvpl

# ==========================================
# 7. 编译终极定制版 FFmpeg (同时启用 NVENC, oneVPL, VAAPI, Opus 等)
# ==========================================
RUN wget https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz && \
    tar -xf ffmpeg-9.0.1.tar.xz && \
    cd ffmpeg-9.0.1 && \
    ./configure \
        --prefix=/usr/local \
        --enable-shared \
        --disable-static \
        --enable-pic \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-openssl \
        --enable-libopus \
        --enable-libvpx \
        --enable-libaom \
        --enable-vaapi \
        --enable-libvpl \
        --enable-nvenc \
        --enable-nvdec \
        --disable-doc \
        --disable-ffplay && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/ffmpeg-9.0.1*

# 清理暂存盘
RUN rm -rf /tmp/*

WORKDIR /workspace
CMD ["/usr/sbin/sshd", "-D"]
