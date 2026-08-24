FROM arthurch9102/bullseye-gcc16:latest
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# 补充安装 libpsl 开发包，供 libcurl 使用
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpsl-dev \
    libnghttp2-dev \
    libbrotli-dev \
    libzstd-dev \
    libssh2-1-dev \
    libidn2-dev \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 1. 源码编译安装最新版 NASM 3.02 (.tar.gz)
# ==========================================
RUN wget https://www.nasm.us/pub/nasm/releasebuilds/3.02/nasm-3.02.tar.gz && \
    tar -xzf nasm-3.02.tar.gz && \
    cd nasm-3.02 && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/nasm-3.02*

# ==========================================
# 6. 源码编译安装最新版 libcurl (绑定 OpenSSL 3.x)
# ==========================================
RUN wget https://curl.se/download/curl-8.21.0.tar.gz && \
    tar -xzf curl-8.21.0.tar.gz && \
    cd curl-8.21.0 && \
    cmake -B build -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_ARES=OFF \
        -DCMAKE_USE_OPENSSL=ON \
        -DOPENSSL_ROOT_DIR=/usr/local/openssl \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_CURL_EXE=ON && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    cd / && rm -rf /tmp/curl-8.21.0*

# ==========================================
# 1. 编译现代高性能内存分配器：mimalloc
# ==========================================
RUN git clone --depth 1 --branch v3.5.0 https://github.com/microsoft/mimalloc.git /tmp/mimalloc && \
    cd /tmp/mimalloc && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DMI_BUILD_SHARED=ON -DMI_BUILD_STATIC=ON -DCMAKE_BUILD_TYPE=Release && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/mimalloc

# ==========================================
# 2. 编译高性能无锁并发队列：concurrentqueue
# ==========================================
RUN git clone --depth 1 --branch v1.0.5 https://github.com/cameron314/concurrentqueue.git /tmp/concurrentqueue && \
    cd /tmp/concurrentqueue && \
    mkdir build_ && cd build_ && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release && \
    ninja install && \
    cd / && rm -rf /tmp/concurrentqueue

# ==========================================
# 3. 编译 Sentry 崩溃捕获 SDK (sentry-native)
# ==========================================
RUN git clone --depth 1 --branch 0.16.3 --recursive https://github.com/getsentry/sentry-native.git /tmp/sentry-native && \
    cd /tmp/sentry-native && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DSENTRY_BUILD_EXAMPLES=OFF -DSENTRY_BUILD_TESTS=OFF && \
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
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF -DCMAKE_BUILD_TYPE=Release && \
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
        --disable-gpl \
        --enable-version3 \
        --disable-doc \
        --disable-everything \
        --enable-vaapi \
        --enable-libsvtav1 \
        --enable-encoder=h264_vaapi,h264_qsv,h264_v4l2m2m,av1_vaapi,av1_v4l2m2m,av1_qsv,aac,libsvtav1,libopenh264,hevc_vaapi,hevc_qsv,hevc_v4l2m2m,h264_nvenc,av1_nvenc,hevc_nvenc \
        --enable-indev=v4l2,kmsgrab,xcbgrab \
        --enable-parser=h264,av1,aac,hevc \
        --enable-muxer=matroska,ivf,rtp,rtsp,h264,av1,hevc \
        --enable-demuxer=matroska,ivf,rtp,rtsp,h264,av1,hevc \
        --enable-protocol=file,pipe \
        --enable-filter=scale,scale_qsv,scale_vaapi,format,aresample,hwmap,hwdownload,anull,pan,scale_cuda \
        --enable-avdevice \
        --enable-libopenh264 \
        --enable-libvpl \
        --enable-decoder=av1,av1_qsv,h264,h264_qsv,h264_v4l2m2m,libopenh264,hevc_qsv,hevc_v4l2m2m,hevc \
        --enable-hwaccel=av1_vaapi,h264_vaapi,hevc_vaapi,av1_nvdec,h264_nvdec,hevc_nvdec && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/ffmpeg-9.0.1*

# 清理暂存盘
RUN rm -rf /tmp/*

WORKDIR /workspace
CMD ["/usr/sbin/sshd", "-D"]
