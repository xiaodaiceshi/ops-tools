#!/bin/sh

# 配置路径
IPTABLES_SAVE_FILE="/etc/iptables/rules.v4"
AUTOSTART_SCRIPT="/etc/init.d/port_forward"
BACKUP_DIR="/root/port_forward_backup"

IPTABLES_BIN="$(command -v iptables 2>/dev/null)"
IPTABLES_SAVE_BIN="$(command -v iptables-save 2>/dev/null)"
IPTABLES_RESTORE_BIN="$(command -v iptables-restore 2>/dev/null)"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$IPTABLES_SAVE_FILE")"

require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "❌ 需要 root 权限运行"
        exit 1
    fi
}

require_cmds() {
    if [ -z "$IPTABLES_BIN" ]; then
        echo "❌ 未找到 iptables，请确认系统已安装并启用 (非 nftables-only 环境)"
        exit 1
    fi
}

is_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *)
            [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ]
            return $? ;;
    esac
}

auto_backup() {
    [ -n "$IPTABLES_SAVE_BIN" ] || return 0
    FILENAME="$BACKUP_DIR/iptables_auto_$(date +%Y%m%d_%H%M%S).backup"
    "$IPTABLES_SAVE_BIN" > "$FILENAME"
}

# 保存并启用开机自启
save_rules() {
    if [ -n "$IPTABLES_SAVE_BIN" ]; then
        "$IPTABLES_SAVE_BIN" > "$IPTABLES_SAVE_FILE"
    fi
    if [ ! -f "$AUTOSTART_SCRIPT" ]; then
cat <<EOF > $AUTOSTART_SCRIPT
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -f "$IPTABLES_SAVE_FILE" ] && iptables-restore < "$IPTABLES_SAVE_FILE"
}
EOF
        chmod +x "$AUTOSTART_SCRIPT"
        /etc/init.d/port_forward enable
        echo "✅ 规则已持久化，开机自启已就绪。"
    fi
}

# 1. 添加转发 (支持端口映射)
add_ports() {
    read -p "请输入内网目标 IP: " DEST_IP
    [ -z "$DEST_IP" ] && echo "❌ 不能为空" && return

    read -p "请输入外部监听端口: " SRC_PORT
    if ! is_port "$SRC_PORT"; then
        echo "❌ 外部端口无效"
        return
    fi

    read -p "请输入内部目标端口 (留空与外部一致): " DST_PORT
    [ -z "$DST_PORT" ] && DST_PORT=$SRC_PORT
    if ! is_port "$DST_PORT"; then
        echo "❌ 内部端口无效"
        return
    fi

    auto_backup
    for PROTO in tcp udp; do
        if ! "$IPTABLES_BIN" -t nat -C PREROUTING -p "$PROTO" --dport "$SRC_PORT" -j DNAT --to-destination "$DEST_IP:$DST_PORT" 2>/dev/null; then
            "$IPTABLES_BIN" -t nat -A PREROUTING -p "$PROTO" --dport "$SRC_PORT" -j DNAT --to-destination "$DEST_IP:$DST_PORT"
            # 解决旁路由回程问题的 MASQUERADE
            if ! "$IPTABLES_BIN" -t nat -C POSTROUTING -p "$PROTO" -d "$DEST_IP" --dport "$DST_PORT" -j MASQUERADE 2>/dev/null; then
                "$IPTABLES_BIN" -t nat -A POSTROUTING -p "$PROTO" -d "$DEST_IP" --dport "$DST_PORT" -j MASQUERADE
            fi
            echo "✨ 已添加 $PROTO: $SRC_PORT -> $DEST_IP:$DST_PORT"
        fi
    done
    save_rules
}

format_rule_line() {
    echo "$1" | awk '{
        proto=""; dport=""; to="";
        for (i=1;i<=NF;i++) {
            if ($i=="-p") proto=$(i+1);
            if ($i=="--dport") dport=$(i+1);
            if ($i=="--to-destination") to=$(i+1);
        }
        if (to!="") printf("协议:%s 外部端口:%s -> %s", proto, dport, to);
    }'
}

# 2. 查看当前规则
view_ports() {
    echo "================ 当前转发规则列表 ================"
    ID=1
    "$IPTABLES_BIN" -t nat -S PREROUTING | grep DNAT | while read -r LINE; do
        INFO=$(format_rule_line "$LINE")
        if [ -n "$INFO" ]; then
            echo "ID:$ID $INFO"
            ID=$((ID + 1))
        fi
    done
    echo "=================================================="
}

# 3. 删除特定规则
delete_ports() {
    read -p "请输入要删除的外部监听端口: " SRC_PORT
    if ! is_port "$SRC_PORT"; then
        echo "❌ 外部端口无效"
        return
    fi

    read -p "请输入对应内网 IP: " DEST_IP
    [ -z "$DEST_IP" ] && echo "❌ 不能为空" && return

    auto_backup
    FOUND=0
    "$IPTABLES_BIN" -t nat -S PREROUTING | grep DNAT | while read -r LINE; do
        echo "$LINE" | grep -q "--dport $SRC_PORT" || continue
        echo "$LINE" | grep -q "--to-destination $DEST_IP" || continue

        PROTO=$(echo "$LINE" | awk '{for(i=1;i<=NF;i++){if($i=="-p"){print $(i+1); exit}}}')
        TO=$(echo "$LINE" | awk '{for(i=1;i<=NF;i++){if($i=="--to-destination"){print $(i+1); exit}}}')
        DST_P=$(echo "$TO" | cut -d: -f2)

        RULE_SPEC="${LINE#-A }"
        "$IPTABLES_BIN" -t nat -D $RULE_SPEC
        if "$IPTABLES_BIN" -t nat -C POSTROUTING -p "$PROTO" -d "$DEST_IP" --dport "$DST_P" -j MASQUERADE 2>/dev/null; then
            "$IPTABLES_BIN" -t nat -D POSTROUTING -p "$PROTO" -d "$DEST_IP" --dport "$DST_P" -j MASQUERADE
        fi
        echo "🗑️ 已删除 $PROTO: $SRC_PORT -> $DEST_IP:$DST_P"
        FOUND=1
    done

    if [ "$FOUND" -eq 0 ]; then
        echo "⚠️ 未找到匹配规则"
    fi

    save_rules
}

# 4. 导出备份
export_rules() {
    if [ -z "$IPTABLES_SAVE_BIN" ]; then
        echo "❌ 未找到 iptables-save，无法导出备份"
        return
    fi
    FILENAME="$BACKUP_DIR/iptables_$(date +%Y%m%d_%H%M%S).backup"
    "$IPTABLES_SAVE_BIN" > "$FILENAME"
    echo "💾 备份成功: $FILENAME"
}

# 5. 恢复备份
import_rules() {
    if [ -z "$IPTABLES_RESTORE_BIN" ]; then
        echo "❌ 未找到 iptables-restore，无法恢复备份"
        return
    fi
    echo "📂 当前可用备份文件："
    LIST=$(ls -1 "$BACKUP_DIR"/*.backup 2>/dev/null)
    if [ -z "$LIST" ]; then
        echo "❌ 未找到任何备份文件"
        return
    fi
    echo "$LIST"
    read -p "请输入备份文件的完整路径: " FILE
    if [ -f "$FILE" ]; then
        auto_backup
        "$IPTABLES_BIN" -t nat -F  # 清空当前 NAT 表防止冲突
        "$IPTABLES_RESTORE_BIN" < "$FILE"
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
        auto_backup
        "$IPTABLES_BIN" -t nat -F
        save_rules
        echo "🔥 已清空所有 NAT 转发规则"
    fi
}

# 7. 搜索功能
search_ip() {
    read -p "请输入要查询的内网 IP: " KEY
    "$IPTABLES_BIN" -t nat -S PREROUTING | grep DNAT | grep "$KEY"
}

require_root
require_cmds

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
