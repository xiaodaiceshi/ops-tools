# OpenWrt Port Forwarding Tool

这个脚本用于在 OpenWrt 旁路由环境下管理端口转发。

### 特点
* 支持非对称端口映射 (例如外网 2222 -> 内网 22)。
* 自动处理 MASQUERADE 伪装，解决旁路由回程断连问题。
* 支持规则持久化（重启不丢失）和备份恢复功能。

### 快速安装使用
```bash
wget -O portfw.sh [https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/portfw.sh](https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/portfw.sh)
chmod +x portfw.sh
./portfw.sh
\```