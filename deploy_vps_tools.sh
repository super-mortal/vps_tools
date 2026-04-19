#!/bin/bash

################################################################################
#
# VPS Tools 部署引导脚本
#
# 功能说明：
#   按顺序引导用户选择并安装 VPS Tools 各组件，自动处理依赖关系
#
# 使用方法：
#   chmod +x deploy_vps_tools.sh
#   ./deploy_vps_tools.sh
#
# 依赖关系：
#   0.nginx     → 必选（所有服务的基础）
#   01.docker   → 推荐（Docker 容器服务的前置依赖）
#
# 作者博客：https://supermortal.cn
#
################################################################################

# ==================== 广告信息 ====================
echo -e "\033[36m"
echo "     ██╗  ██╗ ██████╗ ██╗    ██╗    ██████╗ ██╗██████╗ ";
echo "     ██║  ██║██╔═══██╗██║    ██║    ██╔══██╗██║██╔══██╗";
echo "     ███████║██║   ██║██║ █╗ ██║    ██║  ██║██║██║  ██║";
echo "     ██╔══██║██║   ██║██║███╗██║    ██║  ██║██║██║  ██║";
echo "     ██║  ██║╚██████╔╝╚███╔███╔╝    ██████╔╝██║██████╔╝";
echo "     ╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝     ╚═════╝ ╚═╝╚═════╝ ";
echo ""
echo -e "\033[0m"
echo -e "\033[33m  ★ 博客：https://supermortal.cn ★\033[0m"
echo -e "\033[33m  ★ GitHub：https://github.com/super-mortal ★\033[0m"
echo ""

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ==================== 全局变量 ====================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLED_SERVICES=()
NGINX_INSTALLED=false
DOCKER_INSTALLED=false
NODEJS_INSTALLED=false

# ==================== 辅助函数 ====================

# 引入 Docker 安装脚本（提供 ensure_docker 函数）
DOCKER_INSTALLER="$SCRIPT_DIR/install_docker.sh"
if [ -f "$DOCKER_INSTALLER" ]; then
    source "$DOCKER_INSTALLER"
fi

# 引入 Node.js 安装脚本（提供 ensure_nodejs 函数）
NODEJS_INSTALLER="$SCRIPT_DIR/install_nodejs.sh"
if [ -f "$NODEJS_INSTALLER" ]; then
    source "$NODEJS_INSTALLER"
fi

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║                    🚀 VPS Tools 部署引导工具                                  ║"
    echo "║                                                                              ║"
    echo "║                         版本: v1.0  |  2026-04-11                            ║"
    echo "║                                                                              ║"
    echo "║                    📌 博客: https://supermortal.cn                            ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_divider() {
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}▶ $1${NC}"
    print_divider
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        l|L) return 2 ;;
        t|T) exit 0 ;;
        *) return 1 ;;
    esac
}

wait_key() {
    echo ""
    local key
    read -p "按 L 返回选择组件，按 T 退出..." key
    case "$key" in
        l|L) return 2 ;;
        t|T) exit 0 ;;
    esac
    return 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 必须使用 root 权限运行此脚本。${NC}"
        echo -e "${YELLOW}请使用: sudo ./deploy_vps_tools.sh${NC}"
        exit 1
    fi
}

# ==================== 服务安装函数 ====================

install_nginx() {
    print_section "安装 Nginx 1.28.1 (HTTP/3)"

    echo -e "${WHITE}功能说明:${NC}"
    echo "  • Nginx 1.28.1 源码编译安装，支持最新的 HTTP/3 (QUIC) 协议"
    echo "  • 自动开启 TCP BBR 拥塞控制算法，提升网络性能 20-30%"
    echo "  • 优化系统内核参数，提升文件描述符限制"
    echo "  • 构建模块化配置结构 (conf.d/)，方便后续服务扩展"
    echo "  • 编译 Stream 模块，支持四层 TCP/UDP 负载均衡"
    echo ""
    echo -e "${YELLOW}⚠️  推荐安装，作为 Web 服务器基础${NC}"
    echo ""
    echo -e "${DIM}预计安装时间: 5-10 分钟（取决于服务器性能）${NC}"
    echo ""

    if confirm "是否开始安装 Nginx？" "y"; then
        echo ""
        cd "$SCRIPT_DIR"
        chmod +x nginx_install.sh
        ./nginx_install.sh

        if [ $? -eq 0 ]; then
            NGINX_INSTALLED=true
            INSTALLED_SERVICES+=("Nginx 1.28.1")
            echo ""
            echo -e "${GREEN}✓ Nginx 安装成功！${NC}"
        else
            echo -e "${RED}✗ Nginx 安装失败，请检查错误信息。${NC}"
        fi
    else
        echo -e "${YELLOW}已跳过 Nginx 安装${NC}"
    fi

    wait_key
}

install_docker() {
    print_section "安装 Docker 容器环境"

    echo -e "${WHITE}功能说明:${NC}"
    echo "  • Docker 是容器化服务的运行环境"
    echo "  • 包含 Docker Engine 和 Docker Compose 插件"
    echo "  • 自动修复 apt 源问题，支持多种 Linux 发行版"
    echo ""
    echo -e "${YELLOW}⚠️  某些服务需要 Docker 环境（如 NLink-Navigator 等）${NC}"
    echo ""

    if confirm "是否安装 Docker？" "y"; then
        echo ""

        if ensure_docker; then
            DOCKER_INSTALLED=true
            INSTALLED_SERVICES+=("Docker")
            echo ""
            echo -e "${GREEN}✓ Docker 环境就绪！${NC}"
        else
            echo -e "${RED}✗ Docker 安装失败，后续 Docker 服务将无法安装。${NC}"
        fi
    else
        echo -e "${YELLOW}已跳过 Docker 安装${NC}"
    fi

    wait_key
    return $?
}

install_nodejs() {
    print_section "安装 Node.js 20.x 环境"

    echo -e "${WHITE}功能说明:${NC}"
    echo "  • Node.js 20.x (LTS) JavaScript 运行时"
    echo "  • 包含 npm 包管理器"
    echo "  • 使用 NodeSource 官方安装脚本"
    echo ""
    echo -e "${YELLOW}⚠️  如果需要运行 Node.js 应用（如 PM2、NLink 等）需要安装${NC}"
    echo ""

    if confirm "是否安装 Node.js？" "y"; then
        echo ""

        if ensure_nodejs; then
            NODEJS_INSTALLED=true
            INSTALLED_SERVICES+=("Node.js 20.x")
            echo ""
            echo -e "${GREEN}✓ Node.js 环境就绪！${NC}"
        else
            echo -e "${RED}✗ Node.js 安装失败，后续 Node.js 服务将无法安装。${NC}"
        fi
    else
        echo -e "${YELLOW}已跳过 Node.js 安装${NC}"
    fi

    wait_key
    return $?
}

# ==================== 主流程 ====================

print_summary() {
    print_header
    print_section "部署完成总结"

    if [ ${#INSTALLED_SERVICES[@]} -eq 0 ]; then
        echo -e "${YELLOW}本次未安装任何服务。${NC}"
    else
        echo -e "${GREEN}本次已安装以下服务:${NC}"
        echo ""
        for service in "${INSTALLED_SERVICES[@]}"; do
            echo -e "  ${GREEN}✓${NC} $service"
        done
    fi

    echo ""
    print_divider
    echo ""
    echo -e "${WHITE}常用管理命令:${NC}"
    echo ""
    echo "  Nginx:"
    echo "    systemctl status nginx"
    echo "    /usr/local/nginx/sbin/nginx -t"
    echo "    systemctl reload nginx"
    echo ""

    if [ "$DOCKER_INSTALLED" = true ]; then
        echo "  Docker:"
        echo "    docker --version"
        echo "    docker compose version"
        echo "    systemctl status docker"
        echo ""
    fi

    if [ "$NODEJS_INSTALLED" = true ]; then
        echo "  Node.js:"
        echo "    node --version"
        echo "    npm --version"
        echo ""
    fi

    print_divider
    echo ""
    echo -e "${CYAN}感谢使用 VPS Tools 部署工具！${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  📌 博客: https://supermortal.cn${NC}"
    echo -e "${YELLOW}  📌 GitHub: https://github.com/super-mortal${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

main() {
    check_root

    START_CHOICE=true

    while true; do
        print_header
        echo -e "${WHITE}欢迎使用 VPS Tools 部署引导工具！${NC}"
        echo ""
        echo "本工具将引导您按顺序部署 VPS Tools 的各个组件。"
        echo ""
        echo -e "${CYAN}可用组件:${NC}"
        echo "  1. Nginx 1.28.1 (HTTP/3)  - Web 服务器"
        echo "  2. Docker 容器环境        - 容器服务运行环境"
        echo "  3. Node.js 20.x (LTS)    - Node.js 运行时"
        echo ""
        echo -e "${CYAN}📌 博客: https://supermortal.cn${NC}"
        echo ""

        if [ "$START_CHOICE" = true ]; then
            confirm "是否开始部署？" "y"
            result=$?

            if [ $result -eq 2 ]; then
                echo ""
                print_divider
                echo ""
                echo -e "${CYAN}期待下次使用！${NC}"
                echo ""
                exit 0
            elif [ $result -eq 1 ]; then
                echo ""
                print_divider
                echo ""
                echo -e "${CYAN}期待下次使用！${NC}"
                echo ""
                exit 0
            fi
        fi

        START_CHOICE=false

        echo ""
        echo -e "${CYAN}请选择需要部署的组件:${NC}"
        echo "  1. Nginx 1.28.1 (HTTP/3)"
        echo "  2. Docker 容器环境"
        echo "  3. Node.js 20.x (LTS)"
        echo ""
        read -p "请输入编号: " choice

        case "$choice" in
            1) install_nginx ;;
            2) install_docker ;;
            3) install_nodejs ;;
            *)
                echo -e "${YELLOW}无效的选项${NC}"
                echo ""
                ;;
        esac

        result=$?
        if [ $result -eq 2 ]; then
            continue
        fi
    done

    print_summary
}

# ==================== 执行主函数 ====================
main "$@"
