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
echo "2. 选择性删除 Cloudflare 隧道"
echo "3. 完全删除 cloudflared"
read -p "请输入选择的数字: " CHOICE

if [ "$CHOICE" == "1" ]; then
    # 安装 Cloudflare Tunnel
    read -p "请输入隧道名称: " TUNNEL_NAME
    read -p "请输入域名 (如: example.com): " DOMAIN_NAME
    read -p "请输入本地服务端口 (默认为80): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-80}

    echo "正在下载并安装 Cloudflared..."
    curl -L 'https://file.xiercloud.uk/cloudflared-linux-amd64' -o /usr/bin/cloudflared
    chmod +x /usr/bin/cloudflared

    echo "登录 Cloudflare，请在浏览器中完成授权..."
    cloudflared tunnel login

    echo "创建隧道: $TUNNEL_NAME..."
    cloudflared tunnel create $TUNNEL_NAME

    UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    echo "将域名 $DOMAIN_NAME 指向隧道..."
    cloudflared tunnel route dns $TUNNEL_NAME $DOMAIN_NAME

    CONFIG_FILE="/etc/cloudflared/$TUNNEL_NAME.yml"
    echo "配置 Cloudflared..."
    mkdir -p /etc/cloudflared
    cat > $CONFIG_FILE << EOL
tunnel: $UUID
credentials-file: /root/.cloudflared/$UUID.json
ingress:
  - hostname: $DOMAIN_NAME
    service: http://localhost:$LOCAL_PORT
  - service: http_status:404
EOL

    echo "验证配置文件..."
    cloudflared tunnel ingress validate /etc/cloudflared/$TUNNEL_NAME.yml

    echo "测试隧道运行..."
    cloudflared --config $CONFIG_FILE tunnel run $UUID &

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

    systemctl daemon-reload
    systemctl enable cloudflared
    systemctl start cloudflared
    systemctl status cloudflared

    echo "完成！Cloudflare Tunnel 已成功设置并正在运行。"

elif [ "$CHOICE" == "2" ]; then
    echo "列出所有现有的隧道..."
    TUNNELS=$(cloudflared tunnel list | awk 'NR>1 {print $1, $2}')
    if [ -z "$TUNNELS" ]; then
        echo "没有发现任何隧道。"
    else
        echo "可用的隧道列表："
        echo "ID      NAME"
        echo "$TUNNELS"
        read -p "请输入要删除的隧道 ID 或名称: " TUNNEL_INPUT

        # 匹配用户输入的是隧道名称还是隧道ID
        TUNNEL_ID=$(echo "$TUNNELS" | grep "$TUNNEL_INPUT" | awk '{print $1}')
        TUNNEL_NAME=$(echo "$TUNNELS" | grep "$TUNNEL_INPUT" | awk '{print $2}')

        if [ -z "$TUNNEL_ID" ]; then
            echo "隧道 $TUNNEL_INPUT 不存在。"
        else
            echo "清理隧道 $TUNNEL_ID 的活动连接..."
            cloudflared tunnel cleanup $TUNNEL_ID

            echo "正在删除隧道 $TUNNEL_ID..."
            cloudflared tunnel delete $TUNNEL_ID
            echo "隧道 $TUNNEL_ID 已删除。"
            
            # 提示用户手动删除 DNS 记录
            echo -e "${YELLOW}${BOLD}请自行前往 Cloudflare 官网删除与域名 ${TUNNEL_NAME} 相关的 DNS 记录。${RESET}"
        fi
    fi

elif [ "$CHOICE" == "3" ]; then
    # 完全删除 cloudflared
    echo "停止并禁用 Cloudflared 系统服务..."
    systemctl stop cloudflared
    systemctl disable cloudflared

    echo "删除系统服务文件..."
    rm -f /etc/systemd/system/cloudflared.service
    systemctl daemon-reload

    echo "删除 Cloudflared 可执行文件..."
    rm -f /usr/bin/cloudflared

    echo "删除配置文件和隧道凭证..."
    rm -rf /etc/cloudflared
    rm -rf /root/.cloudflared

    echo "删除日志文件..."
    rm -rf /var/log/cloudflared

    echo "Cloudflared 以及所有相关文件已成功删除。"

else
    echo "无效的选择，脚本退出。"
    exit 1
fi
