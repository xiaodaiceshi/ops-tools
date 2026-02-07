## OpenWrt Port Forwarding Tool

这个脚本用于在 OpenWrt 旁路由环境下管理端口转发。

### 特点
- **非对称端口映射**: 支持外网端口与内网端口不一致（例如外网 2222 -> 内网 22）。
- **MASQUERADE 伪装**: 自动处理回程伪装，减少旁路由回程断连问题。
- **规则持久化与备份**: 支持重启不丢失、导出与恢复。

### 快速安装使用
```bash
wget -O portfw.sh https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/portfw.sh
chmod +x portfw.sh
./portfw.sh
```