#!/bin/bash

################################################################################
#
# Node.js 自动安装脚本
#
# 功能说明：
#   1. 检测 Node.js 是否已安装，已安装则显示版本信息
#   2. 使用 NodeSource 官方脚本安装 Node.js 20.x
#   3. 验证安装结果
#
# 支持系统：
#   - Ubuntu 20.04+
#   - Debian 11+
#
# 使用方法：
#   chmod +x install_nodejs.sh
#   ./install_nodejs.sh          # 直接运行
#   source install_nodejs.sh    # 被其他脚本引用（提供 ensure_nodejs 函数）
#
################################################################################

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

# ==================== 日志函数 ====================

_nodejs_log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

_nodejs_log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

_nodejs_log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

_nodejs_log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

_nodejs_log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# ==================== 系统检测 ====================

check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        local distro="$ID"
        local version="$VERSION_CODENAME"
    else
        _nodejs_log_error "无法检测系统发行版"
        return 1
    fi

    case "$distro" in
        ubuntu|debian)
            _nodejs_log_info "检测到系统: $distro $version"
            return 0
            ;;
        *)
            _nodejs_log_error "不支持的发行版: $distro"
            echo -e "${YELLOW}仅支持 Ubuntu/Debian 系统${NC}"
            return 1
            ;;
    esac
}

# ==================== 修复 apt 源 ====================

fix_apt_sources() {
    _nodejs_log_info "检查并修复 apt 源配置..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro="$ID"
        version="$VERSION_CODENAME"
    else
        _nodejs_log_warning "无法检测系统发行版，跳过源修复"
        return 0
    fi

    if [ "$distro" = "debian" ]; then
        echo -e "${DIM}检测到 Debian $version${NC}"

        if [ ! -f /etc/apt/sources.list.bak ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
        fi

        if [ "$version" = "bullseye" ]; then
            if grep -q "security.debian.org bullseye/updates" /etc/apt/sources.list 2>/dev/null; then
                _nodejs_log_warning "修复 Debian 11 安全源路径..."
                sed -i 's|security.debian.org bullseye/updates|security.debian.org/debian-security bullseye-security|g' /etc/apt/sources.list
            fi
            if grep -q "security.debian.org/debian bullseye/updates" /etc/apt/sources.list 2>/dev/null; then
                sed -i 's|security.debian.org/debian bullseye/updates|security.debian.org/debian-security bullseye-security|g' /etc/apt/sources.list
            fi
        fi

        if [ "$version" = "buster" ]; then
            if grep -q "deb.debian.org/debian buster" /etc/apt/sources.list 2>/dev/null; then
                _nodejs_log_warning "Debian 10 已结束支持，切换到 archive 源..."
                sed -i 's|deb.debian.org/debian|archive.debian.org/debian|g' /etc/apt/sources.list
                sed -i 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list
                sed -i '/buster-updates/d' /etc/apt/sources.list
            fi
        fi
    fi

    echo -e "${DIM}更新软件包列表...${NC}"
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    if apt-get update -qq 2>/dev/null; then
        _nodejs_log_success "apt 源配置正常"
        return 0
    else
        _nodejs_log_warning "apt 更新时有警告，尝试继续..."
        apt-get update --allow-releaseinfo-change 2>/dev/null || true
        return 0
    fi
}

# ==================== Node.js 安装核心函数 ====================

ensure_nodejs() {
    # 已安装：检查版本
    if command -v node &> /dev/null; then
        local node_version=$(node --version 2>/dev/null)
        local npm_version=$(npm --version 2>/dev/null)
        _nodejs_log_success "Node.js 已安装 (版本: $node_version, npm: $npm_version)"
        return 0
    fi

    _nodejs_log_step "安装 Node.js 20.x..."
    echo ""

    # 检测系统
    check_distro || return 1

    # 修复 apt 源
    fix_apt_sources

    # 安装必要依赖
    echo -e "${DIM}安装依赖包...${NC}"
    apt-get install -y -qq curl ca-certificates >/dev/null 2>&1

    # 使用 NodeSource 官方脚本安装 Node.js 20.x
    echo -e "${DIM}下载并运行 NodeSource 安装脚本...${NC}"

    if curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; then
        _nodejs_log_info "安装 Node.js 和 npm..."
        apt-get install -y -qq nodejs

        # 验证安装
        if command -v node &> /dev/null; then
            _nodejs_log_success "Node.js 安装成功"
            node --version
            npm --version
            return 0
        else
            _nodejs_log_error "Node.js 安装失败"
            return 1
        fi
    else
        _nodejs_log_error "NodeSource 安装脚本运行失败"
        echo -e "${YELLOW}请手动安装: https://github.com/nodesource/distributions/blob/master/README.md${NC}"
        return 1
    fi
}

# ==================== 直接运行模式 ====================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        _nodejs_log_error "必须使用 root 权限运行此脚本。"
        echo -e "${YELLOW}请使用: sudo ./install_nodejs.sh${NC}"
        exit 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   Node.js 自动安装程序${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ensure_nodejs; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}   Node.js 环境就绪${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "Node.js 版本: $(node --version 2>/dev/null)"
        echo -e "npm 版本:    $(npm --version 2>/dev/null)"
        echo ""
    else
        exit 1
    fi
fi