#!/bin/bash
# ==========================================================
# dns-doctor installer (ops-tools standard)
# Diagnose + Fix DNS & Docker DNS
# ==========================================================

set -e

INSTALL_PATH="/usr/local/bin/dns-doctor"

echo "======================================"
echo " Installing dns-doctor"
echo "======================================"

# ---------- 1. root 权限 ----------
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] 请使用 root 或 sudo 运行"
  exit 1
fi

# ---------- 2. 基础依赖 ----------
need_install() { ! command -v "$1" >/dev/null 2>&1; }

if need_install curl || need_install ip; then
  apt update -y
  apt install -y curl iproute2
fi

# ---------- 3. 安装 dns-doctor ----------
cat > "$INSTALL_PATH" <<'EOF'
#!/bin/bash
# ==========================================================
# dns-doctor : DNS Diagnose & Repair Tool (FULL)
# ==========================================================

LOG_FILE="/var/log/dns-doctor.log"
BACKUP_DIR="/var/backups/dns-doctor"
DNS1="8.8.8.8"
DNS2="1.1.1.1"
TS=$(date +"%Y%m%d-%H%M%S")

mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
exec 3>>"$LOG_FILE"

log() { echo "[$(date '+%F %T')] $*" >&3; }
info() { echo "[INFO] $*"; log "[INFO] $*"; }
ok()   { echo "[ OK ] $*"; log "[ OK ] $*"; }
warn() { echo "[WARN] $*"; log "[WARN] $*"; }
error(){ echo "[ERR ] $*"; log "[ERR ] $*"; }

# ----------------------------------------------------------
# Cloud detection (SAFE, no false positive)
# ----------------------------------------------------------
detect_cloud() {
  # Oracle Cloud
  if curl -s --connect-timeout 1 http://169.254.169.254/opc/v1/instance/ \
    | grep -q '"ocid1\.'; then echo "Oracle Cloud"; return; fi

  # AWS (IMDSv2 ONLY)
  AWS_TOKEN=$(curl -s -X PUT --connect-timeout 1 \
    http://169.254.169.254/latest/api/token \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
  if [ -n "$AWS_TOKEN" ]; then
    if curl -s --connect-timeout 1 \
      -H "X-aws-ec2-metadata-token: $AWS_TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id \
      | grep -q '^i-'; then echo "AWS"; return; fi
  fi

  # Aliyun
  if curl -s --connect-timeout 1 \
    http://100.100.100.200/latest/meta-data/instance-id \
    | grep -q '^i-'; then echo "Aliyun"; return; fi

  # Tencent Cloud
  if curl -s --connect-timeout 1 \
    http://metadata.tencentyun.com/latest/meta-data/instance-id \
    | grep -q '^ins-'; then echo "Tencent Cloud"; return; fi

  # Huawei Cloud (OpenStack)
  if curl -s --connect-timeout 1 \
    http://169.254.169.254/openstack/latest/meta_data.json \
    | grep -q '"uuid"'; then echo "Huawei Cloud"; return; fi

  echo "Unknown"
}

# ----------------------------------------------------------
# Runtime info
# ----------------------------------------------------------
IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
DNS_MODE="static"
systemctl is-active --quiet systemd-resolved && DNS_MODE="resolved"
CLOUD=$(detect_cloud)

# ----------------------------------------------------------
# Checks
# ----------------------------------------------------------
check_dns() {
  ping -c1 google.com >/dev/null 2>&1 && ping -c1 www.baidu.com >/dev/null 2>&1
}

check_docker_dns() {
  command -v docker >/dev/null 2>&1 || return 0
  systemctl is-active --quiet docker || return 0
  docker run --rm busybox nslookup google.com >/dev/null 2>&1
}

# ----------------------------------------------------------
# Fixes
# ----------------------------------------------------------
fix_dns() {
  warn "开始修复宿主机 DNS（模式: $DNS_MODE）"
  mkdir -p "$BACKUP_DIR"

  if [ "$DNS_MODE" = "resolved" ]; then
    mkdir -p "$BACKUP_DIR/netplan-$TS"
    cp /etc/netplan/*.yaml "$BACKUP_DIR/netplan-$TS/" 2>/dev/null
    NETPLAN=$(ls /etc/netplan/*.yaml | head -n1)
    sed -i "/$IFACE:/a\\            nameservers:\n                addresses: [$DNS1, $DNS2]" "$NETPLAN"
    mkdir -p /etc/cloud/cloud.cfg.d
    echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    netplan apply
  else
    cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.$TS" 2>/dev/null
    systemctl stop systemd-resolved 2>/dev/null
    systemctl disable systemd-resolved 2>/dev/null
    echo -e "nameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null
  fi

  ok "宿主机 DNS 修复完成"
}

fix_docker_dns() {
  warn "开始修复 Docker DNS"
  mkdir -p "$BACKUP_DIR/docker-$TS"
  [ -f /etc/docker/daemon.json ] && cp /etc/docker/daemon.json "$BACKUP_DIR/docker-$TS/"
  cat > /etc/docker/daemon.json <<JSON
{
  "dns": ["$DNS1", "$DNS2"]
}
JSON
  systemctl restart docker
  sleep 3
  check_docker_dns && ok "Docker DNS 修复完成" || error "Docker DNS 修复失败"
}

# ----------------------------------------------------------
# Commands
# ----------------------------------------------------------
case "$1" in
  status)
    echo "Cloud      : $CLOUD"
    echo "DNS Mode   : $DNS_MODE"
    echo "Interface  : $IFACE"
    ;;
  check)
    check_dns && ok "宿主机 DNS 正常" || warn "宿主机 DNS 异常"
    check_docker_dns && ok "Docker DNS 正常" || warn "Docker DNS 异常"
    ;;
  fix)
    case "$2" in
      dns)    fix_dns ;;
      docker) fix_docker_dns ;;
      all)
        check_dns || fix_dns
        check_docker_dns || fix_docker_dns
        ;;
      *)
        echo "Usage: dns-doctor fix {dns|docker|all}"
        ;;
    esac
    ;;
  help|--help|-h|"")
    cat <<USAGE
dns-doctor - DNS Diagnose & Repair Tool

Usage:
  dns-doctor status
  dns-doctor check
  dns-doctor fix dns
  dns-doctor fix docker
  dns-doctor fix all
USAGE
    ;;
  *)
    echo "Unknown command"
    ;;
esac
EOF

chmod +x "$INSTALL_PATH"
hash -r

echo
echo "======================================"
echo " dns-doctor 安装完成 ✅"
echo "======================================"
echo
echo "可用命令："
echo "  dns-doctor status"
echo "  dns-doctor check"
echo "  dns-doctor fix dns"
echo "  dns-doctor fix docker"
echo "  dns-doctor fix all"
echo
