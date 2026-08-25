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

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-22 100 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-22 \
    --slave /usr/bin/lld lld /usr/bin/lld-22 \
    --slave /usr/bin/lldb lldb /usr/bin/lldb-22 \
    --slave /usr/bin/clang-format clang-format /usr/bin/clang-format-22 \
    --slave /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-22

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
# 编译现代高性能内存分配器：mimalloc
# ==========================================
RUN git clone --depth 1 --branch v3.5.0 https://github.com/microsoft/mimalloc.git /tmp/mimalloc && \
    cd /tmp/mimalloc && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DMI_BUILD_SHARED=ON -DMI_BUILD_STATIC=ON -DCMAKE_BUILD_TYPE=Release && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/mimalloc

# ==========================================
# 编译高性能无锁并发队列：concurrentqueue
# ==========================================
RUN git clone --depth 1 --branch v1.0.5 https://github.com/cameron314/concurrentqueue.git /tmp/concurrentqueue && \
    cd /tmp/concurrentqueue && \
    mkdir build_ && cd build_ && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release && \
    ninja install && \
    cd / && rm -rf /tmp/concurrentqueue

# ==========================================
# 编译 Sentry 崩溃捕获 SDK (sentry-native)
# ==========================================
RUN git clone --depth 1 --branch 0.16.3 --recursive https://github.com/getsentry/sentry-native.git /tmp/sentry-native && \
    cd /tmp/sentry-native && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DSENTRY_BUILD_EXAMPLES=OFF -DSENTRY_BUILD_TESTS=OFF && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/sentry-native

# ==========================================
# 编译 WebRTC 核心：libdatachannel
# ==========================================
RUN git clone --depth 1 --branch v0.24.5 https://github.com/paullouisageneau/libdatachannel.git /tmp/libdatachannel && \
    cd /tmp/libdatachannel && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF -DCMAKE_BUILD_TYPE=Release && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/libdatachannel

# 源码编译安装最新稳定版 libopus (音频)
RUN cd /tmp && \
    wget https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz && \
    tar -xzf opus-1.6.1.tar.gz && \
    cd opus-1.6.1 && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DOPUS_BUILD_SHARED_LIBRARY=ON && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/opus-1.6.1*

# ==========================================
# 编译 NVIDIA 硬件编解码头文件 (nv-codec-headers)
# ==========================================
RUN git clone --depth 1 --branch n13.1.15.0 https://github.com/FFmpeg/nv-codec-headers.git /tmp/nv-codec-headers && \
    cd /tmp/nv-codec-headers && \
    make -j$(nproc) PREFIX=/usr/local && \
    make install PREFIX=/usr/local && \
    cd / && rm -rf /tmp/nv-codec-headers

# ==========================================
# 编译 Intel oneVPL 硬件加速库 (libvpl)
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

# 源码编译安装最新版 libva (视频加速接口)
RUN cd /tmp && \
    git clone --depth 1 --branch 2.24.1 https://github.com/intel/libva.git /tmp/libva && \
    cd /tmp/libva && \
    meson setup build --prefix=/usr/local -Dlibdir=lib && \
    meson compile -C build && \
    meson install -C build && \
    cd / && rm -rf /tmp/libva

# 源码编译安装 OpenH264
RUN git clone --depth 1 --branch v2.6.0 https://github.com/cisco/openh264.git /tmp/openh264 && \
    cd /tmp/openh264 && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local && \
    cd / && rm -rf /tmp/openh264

# 源码编译安装 OpenH264
RUN git clone --depth 1 --branch v2.6.0 https://github.com/cisco/openh264.git /tmp/openh264 && \
    cd /tmp/openh264 && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local && \
    cd / && rm -rf /tmp/openh264

# 源码编译安装 SVT-AV1
RUN git clone --depth 1 --branch v4.2.0 https://gitlab.com/AOMediaCodec/SVT-AV1.git /tmp/SVT-AV1 && \
    cd /tmp/SVT-AV1 && \
    mkdir build && cd build && \
    cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON && \
    ninja -j$(nproc) && \
    ninja install && \
    cd / && rm -rf /tmp/SVT-AV1

# ==========================================
# 编译终极定制版 FFmpeg (同时启用 NVENC, oneVPL, VAAPI, Opus 等)
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
        --enable-hwaccel=av1_vaapi,h264_vaapi,hevc_vaapi,av1_nvdec,h264_nvdec,hevc_nvdec \
        --disable-programs && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/ffmpeg-9.0.1*

# 7. 设置 zsh 为默认 shell 并安装 Oh My Zsh
RUN chsh -s /usr/bin/zsh root && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended || true

# 清理暂存盘
RUN rm -rf /tmp/*

# 配置 SSH 服务
EXPOSE 22
# 1. 在构建时（Build-time）准备好目录
RUN mkdir -p /run/sshd && chmod 0755 /run/sshd
# 2. 在运行时（Runtime）动态处理 SSH 公钥并前台启动 sshd
CMD ["sh", "-c", "mkdir -p /root/.ssh && chmod 700 /root/.ssh && if [ -n '$SSH_PUBLIC_KEY' ]; then echo '$SSH_PUBLIC_KEY' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys; fi && exec /usr/sbin/sshd -D"]
WORKDIR /workspace
