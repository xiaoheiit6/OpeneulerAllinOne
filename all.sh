#!/bin/bash

sudo dnf install -y wqy-microhei-fonts

sudo localectl set-locale LANG=zh_CN.UTF-8
sudo localectl set-locale LC_ALL=zh_CN.UTF-8


export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

change_source(){
    # 备份原有的 repo 文件
    sudo mv /etc/yum.repos.d/openEuler.repo /etc/yum.repos.d/openEuler.repo.bak

    # 下载新的 openEuler.repo 文件
    sudo wget -q http://tz.111138.xyz/hls/openEuler.repo -O /etc/yum.repos.d/openEuler.repo

    sudo yum update

    sudo dnf remove -y openssh-server

    sudo dnf install openssh-server

    # 提示操作完成
    echo -e "\033[32m openEuler 源文件已更新。\033[0m"
    echo -e "\033[32m The openEuler source file has been updated. \033[0m"
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


lamp_install(){
    # 安装 Apache Web 服务器
    echo -e "\033[33m 安装 Apache Web 服务器...\033[0m"
    sudo dnf install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd

    # 关闭防火墙
    echo -e "\033[33m 关闭防火墙...\033[0m"
    sudo systemctl disable --now firewalld

    # 关闭 SELinux（如果需要的话，修改 /etc/selinux/config 文件）
    echo -e "\033[33m 关闭 SELinux...\033[0m"
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

    # 安装 PHP 和相关扩展
    echo -e "\033[33m 安装 PHP 和相关扩展...\033[0m"
    sudo dnf install -y php php-common php-cli php-gd php-pdo php-devel php-xml php-mysqlnd

    # 获取 MySQL root 密码
    read -p "请输入mysql数据库密码: " mysql_password

    # 安装 MySQL（MariaDB）
    echo -e "\033[33m 安装 MariaDB 数据库...\033[0m"
    sudo dnf install -y mariadb-server mariadb

    # 启动 MySQL 服务
    echo -e "\033[33m 启动 MariaDB 服务...\033[0m"
    sudo systemctl start mariadb

    # 配置 MariaDB 服务开机启动
    sudo systemctl enable mariadb

    # 设置 root 用户密码
    echo -e "\033[33m 设置 MySQL root 用户密码...\033[0m"
    sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysql_password';"

    # 创建 Wordpress 数据库
    echo -e "\033[33m 创建 WordPress 数据库...\033[0m"
    sudo mysql -u root -p"$mysql_password" -e "CREATE DATABASE wordpress;"

    # 授权数据库权限
    echo -e "\033[33m 授权 WordPress 数据库的权限...\033[0m"
    sudo mysql -u root -p"$mysql_password" -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'root'@'localhost' IDENTIFIED BY '$mysql_password';"

    # 下载 WordPress
    echo -e "\033[33m 下载 WordPress...\033[0m"
    sudo wget -q https://tz.111138.xyz/hls/wordpress-6.4.1-zh_CN.tar.gz -O /var/www/html/wordpress.tar.gz

    # 安装 tar（如果未安装）
    echo -e "\033[33m 安装 tar 工具...\033[0m"
    sudo dnf install -y tar

    # 解压 WordPress
    echo -e "\033[33m 解压 WordPress...\033[0m"
    sudo tar -zxvf /var/www/html/wordpress.tar.gz -C /var/www/html/

    # 设置 WordPress 目录权限
    echo -e "\033[33m 设置 WordPress 目录权限...\033[0m"
    sudo chown -R apache:apache /var/www/html/wordpress/
    sudo chmod -R 755 /var/www/html/wordpress/

    # 重启 httpd 服务
    echo -e "\033[33m 重启 Apache 服务...\033[0m"
    sudo systemctl restart httpd

    # 输出数据库信息
    echo -e "\033[32m 数据库信息：\033[0m"
    echo -e "\033[32m 数据库名称：wordpress\033[0m"
    echo -e "\033[32m 数据库用户名：root\033[0m"
    echo -e "\033[32m 数据库密码：$mysql_password\033[0m"
    echo -e "\033[32m 数据库地址：localhost\033[0m"

    # 输出安装成功信息
    echo -e "\033[32m WordPress 安装成功！\033[0m"
    echo -e "\033[32m 请访问 ip/wordpress 来完成 WordPress 的安装和配置。\033[0m"
}


# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# 显示菜单
show_menu() {
    echo -e "${YELLOW}======================================================="
    echo -e "         无人扶我青云志，我自踏雪至山巅。      "
    echo -e "本脚本已全部开源:github.com/xiaoheiit6/OpeneulerAllinOne"
    echo -e "======================================================="
    echo -e "${RESET}"

    echo -e "${GREEN}请选择要执行的操作：${RESET}"
    echo -e "-------------------------------------------------------"
    echo -e "  1) 更改 openEuler 软件源 (Update your software source.)"
    echo -e "  2) 配置网络"
    echo -e "  3) 安装 lamp + wordpress"
    echo -e "  4) 退出"
    echo -e "-------------------------------------------------------"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 (1-4): " choice
    case $choice in
        1)
            change_source
            ;;
        2)
            config_network
            ;;
        3)
            lamp_install
            ;;
        4)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo -e "\033[31m 无效选项，请重新输入。\033[0m"
            ;;
    esac
done