# MaaEnd NAS 部署镜像
#
# 直接下载 GitHub Release 中已构建好的 linux-x86_64 产物（MXU + go-service + cpp-algo + 资源），
# 不在镜像内重新编译，构建速度快、体积小。
#
# MXU 是 Tauri 桌面应用，即便在 Linux 上也需要一个窗口系统才能运行，
# 因此镜像内用 Xvfb 模拟一块虚拟屏幕，并通过 noVNC 把画面转发到浏览器，
# 方便在 NAS 上通过网页配置/操作 MXU（选择任务、连接 ADB 设备等）。
FROM ubuntu:24.04

ARG MAAEND_REPO=quicksilver2000/MaaEnd
ARG MAAEND_VERSION=latest
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:99 \
    APP_DIR=/app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl tar dumb-init \
        android-tools-adb \
        xvfb x11vnc fluxbox novnc websockify \
        libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 libsoup-3.0-0 \
        libgtk-3-0 librsvg2-2 libayatana-appindicator3-1 \
        fonts-noto-cjk fonts-noto-color-emoji; \
    rm -rf /var/lib/apt/lists/*

# Linux 侧 MXU release 只提供 x86_64 产物（上游 MXU 未发布 linux-aarch64 GUI 二进制），
# 因此本镜像只支持 amd64；其他架构在构建期直接失败，避免生成一个跑不起来的镜像。
RUN set -eux; \
    if [ "$TARGETARCH" != "amd64" ]; then \
        echo "MaaEnd docker image only supports linux/amd64 (MXU has no linux-aarch64 build), got: $TARGETARCH" >&2; \
        exit 1; \
    fi

RUN set -eux; \
    if [ "$MAAEND_VERSION" = "latest" ]; then \
        url=$(curl -fsSL "https://api.github.com/repos/${MAAEND_REPO}/releases/latest" \
            | grep -oE '"browser_download_url": *"[^"]*MaaEnd-linux-x86_64-[^"]*\.tar\.gz"' \
            | head -n1 | sed -E 's/.*"(https[^"]+)"/\1/'); \
    else \
        url="https://github.com/${MAAEND_REPO}/releases/download/${MAAEND_VERSION}/MaaEnd-linux-x86_64-${MAAEND_VERSION}.tar.gz"; \
    fi; \
    if [ -z "$url" ]; then \
        echo "Failed to resolve MaaEnd linux-x86_64 release asset url (repo=${MAAEND_REPO}, version=${MAAEND_VERSION})" >&2; \
        exit 1; \
    fi; \
    echo "Downloading $url"; \
    mkdir -p "$APP_DIR"; \
    curl -fL "$url" -o /tmp/maaend.tar.gz; \
    tar -xzf /tmp/maaend.tar.gz -C "$APP_DIR"; \
    rm -f /tmp/maaend.tar.gz; \
    chmod +x "$APP_DIR/MaaEnd" "$APP_DIR/agent/go-service"; \
    find "$APP_DIR/maafw" -type f -name "Maa*" ! -name "*.so" -exec chmod +x {} \; ; \
    [ -f "$APP_DIR/agent/cpp-algo" ] && chmod +x "$APP_DIR/agent/cpp-algo" || true

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# noVNC 网页端口；容器内部真实 VNC 端口固定 5900（供本机调试用，一般无需单独暴露）
EXPOSE 6080

WORKDIR /app

ENTRYPOINT ["dumb-init", "--"]
CMD ["/entrypoint.sh"]
