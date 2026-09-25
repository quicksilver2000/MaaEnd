# NAS Docker 部署指南

把 MaaEnd（go-service + cpp-algo + 资源）打包进 Docker 镜像，在 NAS 上通过 ADB 局域网连接安卓 Pad 运行终末地日常。

提供两种镜像，按 NAS 架构 / 使用习惯二选一：

| 镜像 | 前端 | 支持架构 | 适用场景 |
| --- | --- | --- | --- |
| `docker/Dockerfile`（tag: `latest`） | [MXU](https://github.com/MistEO/MXU)（Tauri 桌面 GUI，noVNC 转发） | 仅 `linux/amd64` | x86_64 NAS，想要和桌面版一致的操作体验 |
| `docker/Dockerfile.web`（tag: `web`） | [MWU](https://github.com/ravizhan/MWU)（Vue3 + FastAPI 纯 Web UI） | `linux/amd64` + `linux/arm64` | **ARM NAS 必选**；或不想要虚拟屏幕/VNC，纯浏览器控制 |

## 原理

### desktop（MXU + noVNC）

- MXU 是 Tauri 桌面应用，Linux 下也需要窗口系统才能运行，因此镜像内用 `Xvfb` 模拟虚拟屏幕。
- 通过 `x11vnc` + `noVNC` 把这块虚拟屏幕转发到浏览器，打开网页即可像用桌面版一样配置/操作 MXU（新建实例、选任务、连接 ADB 设备、设置定时任务等）。
- **仅支持 `linux/amd64`**：上游 MXU 未发布 `linux-aarch64` 的 GUI 二进制，ARM 架构 NAS 无法运行本镜像。

### web（MWU）

- [MWU](https://github.com/ravizhan/MWU) 是社区维护的 MaaFramework 通用 Web UI：FastAPI 后端 + Vue3 前端，启动后直接监听 `0.0.0.0:5566`，天生就是浏览器控制，容器内**不需要**虚拟屏幕/VNC。
- MWU 官方发布了 `linux-aarch64` 构建，弥补了 MXU 只有 `linux-x86_64` 的短板，因此 **ARM NAS 请使用这个镜像**。
- 镜像构建时会下载 MaaEnd 自己的 Release（取 `agent/`、`interface.json`、`resource*`），覆盖到 MWU 官方 Release（自带打包好的 MaaFramework 运行时）之上，两者拼装成一个可运行目录。
- ⚠️ **已知风险**（MWU 是社区项目，非 MaaEnd/MaaFramework 官方维护，其 README 亦注明"尚未 Production-Ready"）：
    - MWU 自带的 MaaFramework 运行时版本由其自身发布时锁定，理论上可能与 MaaEnd 发布时锁定的版本不同，如遇任务无法正常运行，可尝试在构建时把 `MWU_VERSION` 固定为某个已验证可用的版本，而非默认的 `latest`。
    - 首次部署建议实测几个任务确认可正常运行，再接入定时任务。

镜像内均置 `adb`（`android-tools-adb`），配合安卓 Pad 开启的「无线调试 / ADB over TCP」使用。

## 1. 构建镜像（GitHub Actions）

仓库已包含 `.github/workflows/docker.yml`，在你 fork 的仓库（如 `quicksilver2000/MaaEnd`）打一个 Release 后会自动构建并推送到 GHCR：

```
ghcr.io/quicksilver2000/maaend:latest       # desktop（MXU + noVNC），仅 amd64
ghcr.io/quicksilver2000/maaend:<tag>
ghcr.io/quicksilver2000/maaend:web           # web（MWU），amd64 + arm64
ghcr.io/quicksilver2000/maaend:web-<tag>
```

也可以在 Actions 页面手动触发 `docker` workflow，指定要打包的 Release Tag。

> 首次使用请确认 fork 仓库的 Actions 已启用，且 GHCR 镜像默认设为 **Public**（Settings -> Packages），否则 NAS 拉取镜像时需要先 `docker login ghcr.io`。

> 镜像 tag 说明：`latest` / `web` 是「始终跟随最新 Release」的滚动标签；`<tag>` / `web-<tag>` 是固定版本标签（如 `v1.0.0-nas2`）。生产建议固定到具体版本，避免升级后行为变化。

## 2. NAS 上部署

1. 在安卓 Pad 上开启 ADB 网络调试：
   - 安卓 11+：设置 -> 开发者选项 -> 无线调试，记下 `IP:端口`。
   - 或用数据线执行一次 `adb tcpip 5555`，之后即可断开数据线，用 `IP:5555` 连接。
   - 注意：Pad 的 IP 若会变（DHCP），建议在路由器给它绑定静态 IP，否则定时任务会因设备地址变化而失败。
2. **x86_64 NAS（desktop）**：把仓库中的 [docker-compose.yml](../docker-compose.yml) 拷贝到 NAS 任意目录，按需修改：
   - `image`：改成你自己的 GHCR 镜像地址。
   - `VNC_PASSWORD`：建议设置，避免局域网内其他人访问你的 noVNC 页面。

   **ARM NAS / 只要纯 Web（web）**：改用 [docker-compose.web.yml](../docker-compose.web.yml)，把 `image` 改成你自己的 `...:web` 镜像地址。
3. 启动：
   ```bash
   docker compose up -d          # desktop，用 docker-compose.yml
   # 或
   docker compose -f docker-compose.web.yml up -d   # web，ARM NAS 用这个
   ```
4. 浏览器打开对应地址进行配置：
   - desktop：`http://<NAS-IP>:6080/vnc.html`，进入 MXU 后新建实例，控制器选择 ADB，设备地址填 Pad 的 `IP:端口`（首次连接会自动 `adb connect`）；配置资源路径为镜像内已内置的 `resource`/`interface.json`；按需勾选任务、配置定时任务。
   - web：`http://<NAS-IP>:5566`，进入 MWU 后同样先连接 ADB 设备，再勾选任务、配置定时任务。

> 容器内已内置 `adb`（`android-tools-adb`），**NAS 上无需额外安装**。可自检：`docker exec -it maaend adb version`（web 版容器名默认 `maaend`）。

## 3. 数据持久化

- `docker-compose.yml`（desktop）已挂载 `./config:/app/config`（MXU 实例配置、任务列表、定时任务）与 `./debug:/app/debug`（MXU 调试日志）。
- `docker-compose.web.yml`（web）已挂载 `./config:/app/config`（MWU 的 `settings.json` / `task_config.json` / 定时任务数据库等，见 [MWU 项目结构](https://github.com/ravizhan/MWU#-项目文件目录)）。

升级镜像（`docker compose pull && docker compose up -d`）不会丢失上述配置。

## 常见问题

- **ADB 连不上**：确认 NAS 与 Pad 在同一局域网、Pad 无线调试已开启且 IP 未变化；必要时先用数据线 `adb tcpip 5555` 固化一次 TCP 模式。可在容器内手动连一次排障：`docker exec -it maaend adb connect <Pad-IP>:<端口>`。
- **（desktop）画面卡顿/无法渲染**：确认 `shm_size` 至少 `1gb`（webkit2gtk 对共享内存较敏感）。
- **（web）任务执行异常/疑似协议不兼容**：MWU 自带的 MaaFramework 运行时版本独立于 MaaEnd 锁定，构建镜像时可通过 `MWU_VERSION` build-arg 固定到某个已验证可用的版本再重新构建。
- **（web）健康检查**：`docker-compose.web.yml` 已内置 healthcheck（curl 探测 `:5566`），可用 `docker inspect --format '{{.State.Health.Status}}' maaend` 查看；未就绪时 `restart: unless-stopped` 不会反复重启。
- **想要更低延迟/更简单的网络**：可将 `network_mode` 改为 `host`（去掉 `ports` 段），前提是 NAS 的 Docker 支持 host 网络模式。注意 host 模式下 desktop 的 noVNC 仍走 6080、web 走 5566。
- **升级镜像**：`docker compose pull && docker compose up -d`，配置卷（`./config`、`./debug`）不受影响。建议在升级前备份 `./config` 目录。
