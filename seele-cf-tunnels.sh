#!/bin/bash

# 脚本功能：安装并配置 Cloudflare Tunnel 实现内网穿透

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
CONFIG_FILE="/root/.cloudflared/$TUNNEL_NAME.yml"
echo "配置 Cloudflared..."
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
cloudflared service install
systemctl start cloudflared
systemctl status cloudflared

echo "完成！Cloudflare Tunnel 已成功设置并正在运行。"
