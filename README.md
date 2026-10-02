# HomeMind C700 Video / go2rtc C700 Cloud Relay

**HomeMind 的摄像头与视频证据子项目**：基于 go2rtc 接入小米 C700，提供 LAN / 云中继模式、RTSP/WebRTC 输出、SD 时间线索引与受保护的录像保留。

[HomeMind 子项目入口](https://github.com/vickers-rz/HomeMind/tree/main/subprojects/c700-video) · [架构与边界](docs/architecture.md) · [技术说明](docs/technical-guide.md)

HomeMind 仓库直接收录本子项目概览；这里独立维护实现源码和运行文档。本仓库公开维护。当前功能和历史实机记录已核对，线上服务未在本次文档整理中重新验收。

## 能力与状态

| 能力 | 实现 / 证据 | 范围 |
|---|---|---|
| 实时视频 | go2rtc 补丁、LAN/cloud 模式与流探测脚本 | RTSP/WebRTC 入口；不保证任意网络下直连 |
| SD 时间线 | RDT 命令 6 / 11、SQLite 周期索引 | 元数据索引；历史视频下载另行研究 |
| 夜间保留 | N100 planner、Pi agent、离线测试 | 运动/saved/缺段/过期状态保护 |
| 宿主运维 | Mac launchd、N100 init、监控与 HA 状态工具 | 安装与在线健康需分别验证 |
| 视觉 AI | HomeMind 中的后续 Frigate/VLM 路径 | 尚未完成本子项目的语义推荐闭环验收 |

## 快速使用：Mac

需要可用的 `bin/go2rtc` 和填入实际账号信息的 `config/go2rtc.yaml`。示例配置是模板；克隆仓库不代表二进制与凭证已经准备好。服务端口只在可信 LAN/VPN 中开放。

手动运行：

```sh
./start-go2rtc.command cloud
./switch-mode.command status
./stop-go2rtc.command
```

使用 launchd 自启动时：

```sh
./install-autostart.command
./uninstall-autostart.command
```

手动 PID 脚本和 launchd 是不同的管理路径，按当前启动方式停止服务。自启动 plist 带有本机绝对路径，迁移目录或机器前应修改该文件。

- Web UI：`http://127.0.0.1:1984`
- RTSP：`rtsp://127.0.0.1:8554/c700`
- 稳定流名：`c700`；来源：`c700_remote_sim` / `c700_lan`

```sh
./switch-mode.command cloud
./switch-mode.command lan 5
```

切换后按所用管理路径重启。LAN 参数的含义和适用方式以切换脚本为准。

## 文档与源码导航

- [架构、时间语义与执行护栏](docs/architecture.md)
- [技术说明与演示](docs/technical-guide.md)
- [Mac 启停与排障](docs/mac.md)
- [N100 服务管理](docs/n100.md)
- [SD 时间线协议、SQLite 与构建](tools/c700-sd-indexer/README.md)
- [太阳夜间录像保留](tools/night-retention/README.md)
- [协议研究与历史播放/下载边界](docs/xiaomi-history-research.md)
- `patches/`：相对上游 go2rtc 的本地适配源码；不是完整上游实现。
- `tools/android-lab/`：App 侧研究工具；`tools/probe-*` 与监控脚本用于验证和运行观察。

## 可复现性与验证

索引器构建脚本固定默认上游提交 `c245815e75e2a5fd60b4290f12bfc04e55a984d3`，复制本地补丁并执行相关 Go 测试后构建 Linux arm64 helper。需要 Git、Go 和网络，详见索引器文档。

离线保留测试使用临时文件与数据库，依赖 `astral`、`paho-mqtt`：

```sh
cd tools/night-retention
python3 -m unittest -v test_retention
```

单元测试验证策略和执行边界，不能替代摄像头在线测试或真实部署验收。具体版本、设备固件和性能需在现场记录。

## 凭证与研究资料

`config/go2rtc.yaml` 包含实际小米账号凭证，已从 Git 排除；示例配置应保持脱敏。现场日志、抓包、录屏、设备标识和主机地址在公开分享前需脱敏。不要将本地运行配置复制到公开的 HomeMind 文档目录。

## Time Semantics

This project deliberately separates civil recording time from solar geometry:

- Recording filenames such as `00_20260916190000_...mp4` are Beijing civil time (`Asia/Shanghai`, UTC+8). Date folders use the same civil date.
- RDT timestamps are Unix epoch seconds. When shown as clock time, they are rendered in `Asia/Shanghai`.
- Camera/site latitude and longitude are used only by the astronomical model to calculate the real sunset and sunrise instants. Those instants are then expressed in `Asia/Shanghai` before comparison with recordings.
- Do **not** apply a manual longitude/apparent-solar-time correction to filenames, RDT timestamps, or SQLite timestamps; that would double-correct the solar boundary.

## C700 History / SD Timeline

The microSD timeline protocol is now mapped and verified against the physical
C700. `tools/c700-sd-indexer/` uses Xiaomi MISS/CS2 channel 1 (RDT) to read the
camera's SD segment index without downloading video:

- RDT command 6: segment start/duration plus `motion` and `saved` flags.
- RDT command 11: event-type enrichment such as `PeopleMotion` and `Face`.

The Pi production indexer persists this metadata in SQLite every 10 minutes;
event labels are refreshed at most once per hour. See
`tools/c700-sd-indexer/README.md` and `docs/xiaomi-history-research.md`.

The older `tools/xiaomi-history/` prototype remains useful for Mi Home cloud
`eventlist`, playback/download research, and capture workflows. Historical
video download/playback extraction is separate from the now-working SD timeline
indexer.
