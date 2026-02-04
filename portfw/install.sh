#!/bin/sh

# 配置路径
IPTABLES_SAVE_FILE="/etc/iptables/rules.v4"
AUTOSTART_SCRIPT="/etc/init.d/port_forward"
BACKUP_DIR="/root/port_forward_backup"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$IPTABLES_SAVE_FILE")"

# 保存并启用开机自启
save_rules() {
    [ -x /usr/sbin/iptables-save ] && iptables-save > "$IPTABLES_SAVE_FILE"
    if [ ! -f "$AUTOSTART_SCRIPT" ]; then
cat <<EOF > $AUTOSTART_SCRIPT
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -f "$IPTABLES_SAVE_FILE" ] && iptables-restore < "$IPTABLES_SAVE_FILE"
}
EOF
        chmod +x $AUTOSTART_SCRIPT
        /etc/init.d/port_forward enable
        echo "✅ 规则已持久化，开机自启已就绪。"
    fi
}

# 1. 添加转发 (核心修改：支持不同端口映射)
add_ports() {
    read -p "请输入内网目标 IP: " DEST_IP
    [ -z "$DEST_IP" ] && echo "❌ 不能为空" && return

    read -p "请输入外部监听端口: " SRC_PORT
    read -p "请输入内部目标端口 (留空与外部一致): " DST_PORT
    [ -z "$DST_PORT" ] && DST_PORT=$SRC_PORT

    for PROTO in tcp udp; do
        if ! iptables -t nat -C PREROUTING -p $PROTO --dport $SRC_PORT -j DNAT --to-destination $DEST_IP:$DST_PORT 2>/dev/null; then
            iptables -t nat -A PREROUTING -p $PROTO --dport $SRC_PORT -j DNAT --to-destination $DEST_IP:$DST_PORT
            # 解决旁路由回程问题的 MASQUERADE
            iptables -t nat -A POSTROUTING -p $PROTO -d $DEST_IP --dport $DST_PORT -j MASQUERADE
            echo "✨ 已添加 $PROTO: $SRC_PORT -> $DEST_IP:$DST_PORT"
        fi
    done
    save_rules
}

# 2. 查看当前规则
view_ports() {
    echo "================ 当前转发规则列表 ================"
    iptables -t nat -L PREROUTING -n -v --line-number | grep DNAT | awk '{print "ID:"$1, "协议:"$4, "外部端口:"$11, "->", $12}'
    echo "=================================================="
}

# 3. 删除特定规则
delete_ports() {
    read -p "请输入要删除的外部监听端口: " SRC_PORT
    read -p "请输入对应内网 IP: " DEST_IP
    
    for PROTO in tcp udp; do
        EXISTING=$(iptables -t nat -S PREROUTING | grep "\-\-dport $SRC_PORT" | grep "$DEST_IP" | grep "$PROTO")
        if [ -n "$EXISTING" ]; then
            # 提取具体的内部端口用于匹配 POSTROUTING
            DST_P=$(echo "$EXISTING" | grep -oE "$DEST_IP:[0-9]+" | cut -d: -f2)
            iptables -t nat -D PREROUTING -p $PROTO --dport $SRC_PORT -j DNAT --to-destination $DEST_IP:$DST_P
            iptables -t nat -D POSTROUTING -p $PROTO -d $DEST_IP --dport $DST_P -j MASQUERADE
            echo "🗑️ 已删除 $PROTO: $SRC_PORT -> $DEST_IP:$DST_P"
        fi
    done
    save_rules
}

# 4. 导出备份
export_rules() {
    FILENAME="$BACKUP_DIR/iptables_$(date +%Y%m%d_%H%M%S).backup"
    iptables-save > "$FILENAME"
    echo "💾 备份成功: $FILENAME"
}

# 5. 恢复备份 (功能回归)
import_rules() {
    echo "📂 当前可用备份文件："
    LIST=$(ls -1 $BACKUP_DIR/*.backup 2>/dev/null)
    if [ -z "$LIST" ]; then
        echo "❌ 未找到任何备份文件"
        return
    fi
    echo "$LIST"
    read -p "请输入备份文件的完整路径: " FILE
    if [ -f "$FILE" ]; then
        iptables -t nat -F  # 清空当前 NAT 表防止冲突
        iptables-restore < "$FILE"
        save_rules
        echo "✅ 规则已从文件恢复并保存。"
    else
        echo "❌ 文件不存在！"
    fi
}

# 6. 清空所有
clear_all() {
    read -p "⚠️ 确定清空所有端口转发吗？(y/n): " CONFIRM
    if [ "$CONFIRM" = "y" ]; then
        iptables -t nat -F
        save_rules
        echo "🔥 已清空所有 NAT 转发规则"
    fi
}

# 7. 搜索功能
search_ip() {
    read -p "请输入要查询的内网 IP: " KEY
    iptables -t nat -L PREROUTING -n -v | grep DNAT | grep "$KEY"
}

# 菜单循环
while true; do
    echo ""
    echo "🛠️  OpenWrt 旁路由转发工具 (完整增强版)"
    echo "----------------------------------------"
    echo "1) 添加转发 (支持端口转换)"
    echo "2) 查看所有规则"
    echo "3) 删除单条规则"
    echo "4) 导出规则 (备份)"
    echo "5) 恢复规则 (从文件导入)"
    echo "6) 清空所有规则"
    echo "7) 按 IP 搜索规则"
    echo "8) 退出"
    read -p "请选择操作 [1-8]: " CHOICE

    case "$CHOICE" in
        1) add_ports ;;
        2) view_ports ;;
        3) delete_ports ;;
        4) export_rules ;;
        5) import_rules ;;
        6) clear_all ;;
        7) search_ip ;;
        8) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
done