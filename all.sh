#!/bin/bash

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

change_source(){
    # 备份原有的 repo 文件
    sudo mv /etc/yum.repos.d/openEuler.repo /etc/yum.repos.d/openEuler.repo.bak

    # 下载新的 openEuler.repo 文件
    sudo wget -q http://tz.111138.xyz/hls/openEuler.repo -O /etc/yum.repos.d/openEuler.repo

    # 提示操作完成
    echo -e "\033[32m openEuler 源文件已更新。\033[0m"
}

config_network() {
    # 使用ip addr命令获取所有网卡名称
    NICS=$(ip addr | awk '/^[0-9]+:/ {gsub(/:/, "", $2); print $2}')

    # 提示用户目前已有的网卡名称
    echo "目前已有的网卡名称："
    echo -e "\033[33m $NICS \033[0m"

    # 提示用户输入网卡名称、IP 地址和网关
    read -p "请输入网卡名称(如ens36): " NIC
    read -p "请输入 IP 地址(仅主机模式网段下的IP(你想设置的ip)): " IPADDR
    read -p "请输入网关地址(仅主机模式下的网关地址): " GATEWAY

    # 检查用户输入是否为空
    if [[ -z "$NIC" || -z "$IPADDR" || -z "$GATEWAY" ]]; then
        echo "输入不能为空，请重新运行脚本。"
        exit 1
    fi

    # 配置文件路径
    CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$NIC"

    # 备份原配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        echo "已备份原配置文件为：${CONFIG_FILE}.bak"
    fi

    # 写入固定配置和用户输入的 IP 地址、网关
    cat > "$CONFIG_FILE" <<EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
IPADDR=$IPADDR
PREFIX=24
GATEWAY=$GATEWAY
DNS1=119.29.29.29
DNS2=114.114.114.114
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME="$NIC"
UUID=$(uuidgen)
DEVICE=$NIC
ONBOOT=yes
EOF

    echo "网络配置已更新：$CONFIG_FILE"

    # 重新加载 NetworkManager 配置并启用新的连接
    nmcli connection reload

    # 激活新的网络配置
    nmcli c up "$NIC"
    if [[ $? -eq 0 ]]; then
        echo -e "\033[32m 新的网络配置已成功应用。\033[0m"
    else
        echo -e "\033[31m 网络配置应用失败，请检查配置文件。\033[0m"
    fi
}

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# 显示菜单
show_menu() {
    echo -e "${YELLOW}======================================================="
    echo -e "         无人扶我青云志，我自踏雪至山巅。      "
    echo -e "本脚本已全部开源：github.com/xiaoheiit6/OpeneulerAllinOne"
    echo -e "======================================================="
    echo -e "${RESET}"

    echo -e "${GREEN}请选择要执行的操作：${RESET}"
    echo -e "-------------------------------------------------------"
    echo -e "  1) 更改 openEuler 软件源"
    echo -e "  2) 配置网络"
    echo -e "  3) 退出"
    echo -e "-------------------------------------------------------"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 (1-3): " choice
    case $choice in
        1)
            change_source
            ;;
        2)
            config_network
            ;;
        3)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo -e "\033[31m 无效选项，请重新输入。\033[0m"
            ;;
    esac
done