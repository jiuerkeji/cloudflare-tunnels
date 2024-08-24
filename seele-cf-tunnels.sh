#!/bin/bash

# ANSI 转义序列
RED='\033[0;31m'    # 红色
GREEN='\033[0;32m'  # 绿色
YELLOW='\033[1;33m' # 黄色高亮
BLUE='\033[0;34m'   # 蓝色
BOLD='\033[1m'      # 粗体
RESET='\033[0m'     # 重置颜色

# 广告信息
echo -e "${YELLOW}${BOLD}欢迎使用 SeeleCloud 提供的 Cloudflare 内网穿透脚本！${RESET}"
echo -e "${GREEN}${BOLD}便宜好用的机场请访问：${BLUE}https://main.xiercloud.uk${RESET}"
echo ""

# 开始菜单
echo "请选择操作:"
echo "1. 安装 Cloudflare 内网穿透"
echo "2. 彻底删除 Cloudflare 内网穿透 (包括所有相关文件和记录)"
read -p "请输入选择的数字: " CHOICE

if [ "$CHOICE" == "1" ]; then
    # 安装 Cloudflare Tunnel
    # 提示用户输入隧道名称、域名等信息
    read -p "请输入隧道名称: " TUNNEL_NAME
    read -p "请输入域名 (如: example.com): " DOMAIN_NAME
    read -p "请输入本地服务端口 (默认为80): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-80}  # 如果未输入则默认为80

    # 安装 Cloudflared
    echo "正在下载并安装 Cloudflared..."
    curl -L 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64' -o /usr/bin/cloudflared
    chmod +x /usr/bin/cloudflared

    # 登录 Cloudflare
    echo "登录 Cloudflare，请在浏览器中完成授权..."
    cloudflared tunnel login

    # 创建隧道
    echo "创建隧道: $TUNNEL_NAME..."
    cloudflared tunnel create $TUNNEL_NAME

    # 获取创建隧道的 UUID
    UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')

    # 将域名指向隧道
    echo "将域名 $DOMAIN_NAME 指向隧道..."
    cloudflared tunnel route dns $TUNNEL_NAME $DOMAIN_NAME

    # 创建配置文件
    CONFIG_FILE="/etc/cloudflared/$TUNNEL_NAME.yml"
    echo "配置 Cloudflared..."
    mkdir -p /etc/cloudflared
    cat > $CONFIG_FILE << EOL
tunnel: $UUID
credentials-file: /root/.cloudflared/$UUID.json
protocol: h2mux
ingress:
  - hostname: $DOMAIN_NAME
    service: http://localhost:$LOCAL_PORT
  - service: http_status:404
EOL

    # 验证配置文件
    echo "验证配置文件..."
    cloudflared tunnel ingress validate --config $CONFIG_FILE

    # 测试隧道运行
    echo "测试隧道运行..."
    cloudflared --config $CONFIG_FILE tunnel run $UUID &

    # 创建系统服务
    echo "创建系统服务..."
    cat > /etc/systemd/system/cloudflared.service << EOL
[Unit]
Description=cloudflared
After=network.target

[Service]
ExecStart=/usr/bin/cloudflared --config /etc/cloudflared/$TUNNEL_NAME.yml tunnel run
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    # 重新加载 systemd 并启动服务
    systemctl daemon-reload
    systemctl enable cloudflared
    systemctl start cloudflared
    systemctl status cloudflared

    echo "完成！Cloudflare Tunnel 已成功设置并正在运行。"

elif [ "$CHOICE" == "2" ]; then
    # 彻底删除 Cloudflare Tunnel
    echo "彻底删除 Cloudflare Tunnel 以及所有相关文件..."

    # 停止并禁用系统服务
    echo "停止并禁用 Cloudflared 系统服务..."
    systemctl stop cloudflared
    systemctl disable cloudflared

    # 删除系统服务文件
    echo "删除系统服务文件..."
    rm -f /etc/systemd/system/cloudflared.service

    # 重新加载 systemd
    systemctl daemon-reload

    # 删除 Cloudflared 可执行文件
    echo "删除 Cloudflared 可执行文件..."
    rm -f /usr/bin/cloudflared

    # 删除配置文件和隧道凭证
    echo "删除配置文件和隧道凭证..."
    rm -rf /etc/cloudflared
    rm -rf /root/.cloudflared

    # 删除日志文件（如果有）
    echo "删除日志文件..."
    rm -rf /var/log/cloudflared

    # 删除所有隧道
    echo "删除所有隧道..."
    TUNNELS=$(cloudflared tunnel list | awk 'NR>1 {print $1}')
    for TUNNEL_ID in $TUNNELS; do
        echo "正在删除隧道 $TUNNEL_ID..."
        cloudflared tunnel delete $TUNNEL_ID
        echo "隧道 $TUNNEL_ID 已删除。"
    done

    # 删除 Cloudflare 的 DNS 记录
    echo "删除 Cloudflare 的 DNS 记录..."
    DOMAIN_LIST=$(cloudflared tunnel route dns | awk 'NR>1 {print $2}')
    for DOMAIN in $DOMAIN_LIST; do
        echo "删除域名 $DOMAIN 的 DNS 记录..."
        cloudflared tunnel route dns delete $DOMAIN
    done

    echo "Cloudflare Tunnel 以及所有相关文件已成功删除。"

else
    echo "无效的选择，脚本退出。"
    exit 1
fi
