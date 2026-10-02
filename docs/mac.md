# Mac 服务管理与排障

## 确认启动方式

本项目提供手动后台运行和 launchd 自启动两条路径。`stop-go2rtc.command` 读取项目内 `go2rtc.pid`，只能停止该 PID 对应的手动实例。launchd 使用 `com.vickers.go2rtc-c700` 标签管理进程，启用了 KeepAlive，直接 kill 可能被自动拉起。

```sh
launchctl print "gui/$(id -u)/com.vickers.go2rtc-c700"
pgrep -fl go2rtc
```

这里的输出反映执行时状态；不要将历史 PID 当作当前运行证据。

## 手动运行

在项目根目录执行：

```sh
./start-go2rtc.command cloud
./stop-go2rtc.command
```

日志位于 `logs/go2rtc.log`。启动前确认没有另一个实例占用 API/RTSP 端口。

## launchd 自启动

```sh
./install-autostart.command
./uninstall-autostart.command
```

安装脚本复制仓库 plist 到用户 LaunchAgents，再 bootstrap / enable / kickstart。卸载脚本用于停止自启动实例；暂停服务应使用这一管理路径。安装前检查 plist 中程序、配置、工作目录和日志的绝对路径是否与本机一致。

日志为 `logs/go2rtc.launchd.log` 和 `logs/go2rtc.launchd.err.log`，具体以 plist 为准。

## 切换视频来源

```sh
./switch-mode.command cloud
./switch-mode.command lan 5
./switch-mode.command status
```

切换脚本修改稳定流 `c700` 的来源，之后需重启。手动实例执行 stop / start；launchd 实例使用卸载 / 安装脚本。保持一个运行实例，随后验证 `http://127.0.0.1:1984` 与 `rtsp://127.0.0.1:8554/c700`。

## 排障顺序

1. 确认启动路径和日志，检查端口冲突。
2. 检查实际配置与账号授权；排障输出勿分享 token。
3. 分别验证 LAN 或云中继来源，再检查稳定流 `c700`。
4. 有流但无法播放时，检查消费者对视频/音频编码的支持。

本手册描述脚本行为，不代表当前 Mac 服务已启动或摄像头在线。
