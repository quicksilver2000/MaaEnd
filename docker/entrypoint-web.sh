#!/bin/sh
# MWU 启动前初始化 config 目录。
#
# 背景：MWU 只在 /app/config 目录不存在时才创建默认 settings.json。
# 但 docker-compose 用 bind mount 把宿主 config 目录挂到 /app/config 后，
# 该目录已存在（可能为空），MWU 会跳过创建，启动时读取 settings.json 直接崩溃。
# 故在启动前检查，缺文件则写入 MWU 默认配置，保证首次启动可用且配置持久化。
set -e

CONFIG_DIR="${CONFIG_DIR:-/app/config}"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "[entrypoint] creating default $SETTINGS_FILE"
    mkdir -p "$CONFIG_DIR"
    cat > "$SETTINGS_FILE" <<'JSON'
{
    "update": {
        "autoUpdate": true,
        "updateChannel": "stable",
        "proxy": "",
        "mirrorchyanCdk": ""
    },
    "notification": {
        "systemNotification": false,
        "browserNotification": false,
        "externalNotification": false,
        "webhook": "",
        "contentType": "application/json",
        "headers": "",
        "body": "",
        "username": "",
        "password": "",
        "method": "POST",
        "notifyOnComplete": true,
        "notifyOnError": true
    },
    "ui": {
        "darkMode": "auto"
    },
    "runtime": {
        "timeout": 300,
        "reminderInterval": 30,
        "autoRetry": true,
        "maxRetryCount": 3,
        "retryInterval": 5
    },
    "about": {
        "version": "",
        "author": "",
        "github": "",
        "license": "",
        "description": "",
        "contact": "",
        "issueUrl": ""
    },
    "panel": {
        "lastResource": "",
        "lastConnectedDevice": null,
        "recentDevices": null,
        "customDevices": []
    },
    "globalOptionValues": {}
}
JSON
fi

exec dumb-init -- ./MWU