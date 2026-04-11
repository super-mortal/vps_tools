# VPS Tools

一款为 **VPS 新手小白** 打造的 VPS 部署工具箱，帮你快速在服务器上安装 Nginx 以及 docker

## 项目介绍

- 一键安装 Nginx，无需手动编译配置
- 自动安装 acme.sh，告别手动申请证书
- 全自动配置反向代理，开箱即用
- 支持多域名多站点，互不干扰
- 可选 Docker 容器环境支持

## 支持系统

- Ubuntu 20.04+
- Debian 11+
- CentOS Stream 9 / Rocky / AlmaLinux

## 快速开始

### 一键部署

```bash
# 克隆仓库
git clone https://github.com/super-mortal/vps_tools.git

# 进入目录
cd vps_tools

# 给脚本添加执行权限
chmod +x deploy_vps_tools.sh

# 运行部署引导脚本
./deploy_vps_tools.sh
```

部署引导脚本会按顺序提示你安装：

1. **Nginx 1.28.1**（必选）- Web 服务器，支持 HTTP/3
2. **Docker**（可选）- 容器运行环境

### 部署流程图

```
┌─────────────────────────────────────────┐
│         VPS Tools 部署流程              │
├─────────────────────────────────────────┤
│                                         │
│  1. Nginx 安装（必选）                  │
│     ↓                                   │
│  2. Docker 安装（可选）                 │
│     ↓                                   │
│  3. 申请 SSL 证书并配置反向代理         │
│                                         │
└─────────────────────────────────────────┘
```

## 单独安装 Docker

如果只想单独安装 Docker，不使用引导脚本：

```bash
cd vps_tools
chmod +x install_docker.sh
./install_docker.sh
```

**安装过程会自动完成**：
- 检测系统发行版
- 自动修复 apt 源问题
- 安装 Docker Engine 和 Docker Compose 插件
- 启动并设置开机自启

**验证安装**：

```bash
docker --version                    # 查看 Docker 版本
docker compose version              # 查看 Docker Compose 版本
systemctl status docker             # 查看服务状态
docker run --rm hello-world         # 运行测试容器
```

**Docker 常用命令**：

```bash
systemctl start docker              # 启动 Docker
systemctl stop docker               # 停止 Docker
systemctl restart docker            # 重启 Docker
systemctl enable docker             # 开机自启
docker ps                           # 查看运行中的容器
docker compose up -d                # 启动 docker-compose 服务
docker compose down                 # 停止 docker-compose 服务
docker compose logs -f              # 查看 docker-compose 日志
```

## 申请 SSL 证书

在 Nginx 安装完成后，为你的域名申请 SSL 证书并自动配置反向代理：

```bash
chmod +x ssl_cert.sh
./ssl_cert.sh -d 你的域名 -s 服务名 -p 端口号
```

**参数说明**：

| 参数 | 必须 | 说明 | 示例 |
|------|------|------|------|
| `-d` | 是 | 你的域名 | `-d api.example.com` |
| `-s` | 是 | 服务名称（随意起，用于生成配置文件） | `-s api` |
| `-p` | 是 | Docker 映射到主机的端口 | `-p 8088` |

**完整示例**：

```bash
# 假设：
# 你的域名是：mysite.com
# Docker 容器映射到主机的端口是：8080

./ssl_cert.sh -d mysite.com -s mysite -p 8080
```

### 交互式使用

如果不确定参数，可以直接运行，脚本会引导你输入：

```bash
./ssl_cert.sh
```

会依次提示输入：
1. 域名（如 `api.example.com`）
2. 服务名称（如 `Nav`）
3. 端口号（如 `8080`）

## Nginx 常用命令

```bash
/usr/local/nginx/sbin/nginx -t           # 测试 Nginx 配置是否正确
/usr/local/nginx/sbin/nginx -s reload    # 重载 Nginx（修改配置后需要执行）
systemctl restart nginx                   # 重启 Nginx
systemctl status nginx                    # 查看 Nginx 服务状态
```

## acme.sh 常用命令

```bash
/root/.acme.sh/acme.sh --list                    # 查看证书列表
/root/.acme.sh/acme.sh --info -d 你的域名        # 查看证书详情
/root/.acme.sh/acme.sh --renew -d 你的域名 --force  # 手动续期证书
crontab -l | grep acme                           # 查看自动续期任务
```

## 文件路径

### Nginx 相关

| 用途 | 路径 |
|------|------|
| Nginx 主配置 | `/usr/local/nginx/conf/nginx.conf` |
| 站点配置目录 | `/usr/local/nginx/conf/conf.d/` |
| SSL 证书目录 | `/usr/local/nginx/conf/ssl/` |
| acme.sh 目录 | `/root/.acme.sh/` |

### Docker 相关

| 用途 | 路径 |
|------|------|
| Docker 数据目录 | `/var/lib/docker` |
| Docker 配置目录 | `/etc/docker` |
| Docker socket | `/var/run/docker.sock` |

## 多站点部署

每个站点都有独立的配置文件，互不干扰。配置目录结构如下：

```
/usr/local/nginx/conf/conf.d/
├── mysite.com.conf      # 站点1
├── api.example.com.conf  # 站点2
└── blog.test.com.conf    # 站点3
```

只需为每个新站点运行一次 SSL 脚本即可：

```bash
# 站点1
./ssl_cert.sh -d mysite.com -s mysite -p 8088

# 站点2
./ssl_cert.sh -d api.example.com -s api -p 3000

# 站点3
./ssl_cert.sh -d blog.test.com -s blog -p 5000
```

## 常见问题

### Q: 申请证书时报 "Domain is not point to this server"

**原因**：域名 DNS 还没解析到当前服务器。

**解决**：等待几分钟让 DNS 生效，或检查域名 A 记录是否指向当前服务器 IP。

### Q: HTTPS 能访问但显示不安全

**原因**：可能是旧的自签名证书或浏览器缓存。

**解决**：
```bash
# 删除旧证书重新申请
/root/.acme.sh/acme.sh --remove -d 你的域名
./ssl_cert.sh -d 你的域名 -s 服务名 -p 端口号
```

### Q: 证书多久续期一次？

**回答**：Let's Encrypt 证书有效期 90 天。acme.sh 会在到期前 30 天自动续期，正常情况下不需要手动操作。

### Q: Docker 安装失败怎么办？

**回答**：脚本会自动修复大多数常见的 apt 源问题。如果仍然失败，请检查：
1. 网络连接是否正常
2. 系统是否在支持列表中（Ubuntu 20.04+, Debian 11+, CentOS Stream 9等）
3. 可以尝试手动安装：https://docs.docker.com/engine/install/

### Q: 什么情况下需要安装 Docker？

**回答**：如果只是使用 Nginx 反向代理非容器化的服务（如直接运行在服务器上的 Node.js、Python 应用等），不需要安装 Docker。只有在使用 Docker 容器部署的服务时才需要安装。

---

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。
