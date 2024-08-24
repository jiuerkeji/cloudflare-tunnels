## 使用 Cloudflare 内网穿透脚本 `cf-tunnels.sh` 教程

本脚本用于管理 Cloudflare Tunnel 的安装、隧道删除以及 cloudflared 的完全删除操作。通过此脚本，您可以方便地安装 Cloudflare 内网穿透隧道、选择性删除隧道或完全删除 Cloudflared 相关文件。

### 1. 准备工作

在开始使用脚本之前，请确保以下条件满足：
- 您已经拥有一个 [Cloudflare 账号](https://dash.cloudflare.com/) 并添加了相关域名。
- 您的服务器运行的是 Linux 操作系统。
- 您可以通过 SSH 登录服务器并具有 `sudo` 权限。

### 2. 下载并安装脚本

首先，您需要下载脚本并为其添加执行权限。可以通过以下命令来完成这些操作：

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/jiuerkeji/cloudflare-tunnels/main/cf-tunnels.sh

# 添加执行权限
sudo chmod +x cf-tunnels.sh
```

### 3. 运行脚本

运行脚本时，您可以选择三种操作：安装 Cloudflare Tunnel、选择性删除隧道或完全删除 `cloudflared`。运行脚本的命令如下：

```bash
sudo ./cf-tunnels.sh
```

### 4. 使用选项说明

当运行脚本时，会出现一个菜单供您选择执行的操作：

```bash
请选择操作:
1. 安装 Cloudflare 内网穿透
2. 选择性删除 Cloudflare 隧道
3. 完全删除 cloudflared
```

#### 4.1. 安装 Cloudflare 内网穿透

选择 **1** 安装 Cloudflare Tunnel。安装过程如下：

- **输入隧道名称**：输入您想创建的隧道名称，例如 `mytunnel`。
- **输入域名**：输入您已添加到 Cloudflare 的域名，例如 `example.com`。
- **输入本地服务端口**：默认情况下，隧道会将请求转发到本地服务端口 `80`，您可以更改此端口。

脚本会执行以下操作：
- 下载并安装 `cloudflared`。
- 登录 Cloudflare 进行授权。
- 创建隧道并将域名指向该隧道。
- 配置系统服务以确保隧道在服务器启动时自动运行。

完成后，隧道将正常启动并运行。

#### 4.2. 选择性删除 Cloudflare 隧道

选择 **2** 可以列出所有现有的隧道，并选择要删除的隧道。删除过程如下：

- **列出隧道**：脚本会列出所有当前存在的隧道及其 ID 和名称。
- **输入要删除的隧道 ID 或名称**：您可以根据列出的信息输入要删除的隧道名称或隧道 ID。

脚本会执行以下操作：
- 清理隧道的活动连接。
- 删除指定的隧道。

**注意**：隧道删除后，系统会提示您自行前往 Cloudflare 官网删除与该隧道相关的 DNS 记录。例如：

```bash
请自行前往 Cloudflare 官网删除与域名 mytunnel 相关的 DNS 记录。
```

您需要登录 Cloudflare 控制台并手动删除与该隧道相关的 DNS 记录。

#### 4.3. 完全删除 Cloudflared

选择 **3** 将完全删除 `cloudflared` 及其所有相关文件和配置。这适用于不再需要 Cloudflare 内网穿透服务的情况。脚本会执行以下操作：

- 停止并禁用 `cloudflared` 系统服务。
- 删除 `cloudflared` 的可执行文件、配置文件、凭证文件和日志文件。

执行此操作后，所有与 `cloudflared` 相关的内容将从您的服务器中移除。

---

### 5. 注意事项

- **删除 DNS 记录**：在删除隧道后，您需要手动前往 Cloudflare 官网删除与隧道相关的 DNS 记录，脚本会提供高亮提示。
- **定期检查隧道**：如果不再需要某个隧道，请通过此脚本或 Cloudflare 控制台进行清理，避免不必要的资源占用。
- **保持 `cloudflared` 更新**：如需要继续使用 Cloudflare Tunnel，请定期检查并更新 `cloudflared`，以确保稳定性和安全性。

---

