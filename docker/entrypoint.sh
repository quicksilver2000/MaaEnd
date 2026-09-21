#!/usr/bin/env bash
# MaaEnd 容器入口：拉起虚拟显示 + noVNC，再启动 MXU（即 install 产物中的 MaaEnd 可执行文件）。
set -euo pipefail

DISPLAY_NUM="${DISPLAY#:}"
RESOLUTION="${DISPLAY_RESOLUTION:-1280x720x24}"
VNC_PORT=5900
NOVNC_PORT="${NOVNC_PORT:-6080}"

pids=()
cleanup() {
    trap - TERM INT
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait || true
}
trap cleanup TERM INT

echo "[entrypoint] starting Xvfb :${DISPLAY_NUM} (${RESOLUTION})"
Xvfb ":${DISPLAY_NUM}" -screen 0 "${RESOLUTION}" -nolisten tcp &
pids+=("$!")

# 等待 Xvfb 就绪，避免后续程序连接到还没起来的虚拟屏幕
for _ in $(seq 1 50); do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

echo "[entrypoint] starting fluxbox window manager"
fluxbox >/tmp/fluxbox.log 2>&1 &
pids+=("$!")

if [ -n "${VNC_PASSWORD:-}" ]; then
    x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/vncpasswd
    echo "[entrypoint] starting x11vnc (password protected)"
    x11vnc -display "${DISPLAY}" -forever -shared -rfbauth /tmp/vncpasswd -rfbport "${VNC_PORT}" -quiet >/tmp/x11vnc.log 2>&1 &
else
    echo "[entrypoint] starting x11vnc (no password, please protect via network/firewall)"
    x11vnc -display "${DISPLAY}" -forever -shared -nopw -rfbport "${VNC_PORT}" -quiet >/tmp/x11vnc.log 2>&1 &
fi
pids+=("$!")

echo "[entrypoint] starting noVNC on port ${NOVNC_PORT}"
websockify --web=/usr/share/novnc "${NOVNC_PORT}" "localhost:${VNC_PORT}" >/tmp/novnc.log 2>&1 &
pids+=("$!")

echo "[entrypoint] launching MaaEnd (MXU), open http://<NAS-IP>:${NOVNC_PORT}/vnc.html to configure"
cd "${APP_DIR:-/app}"
./MaaEnd &
main_pid=$!
pids+=("$main_pid")

wait "$main_pid"
