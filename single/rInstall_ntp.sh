#!/usr/bin/env bash
################################################################################
## Name: NTP 同步时间和时区
## Author:  skycoop
## Version: 1.0
## 
## 仅适用于CentOS7系统
################################################################################

# 设置中国时区
timedatectl set-timezone "Asia/Shanghai"
# 开启NTP服务
timedatectl set-ntp true

# 1. 检测是否存在 yum install chrony
systemctl status chronyd.service 2> /dev/null

if test $? -ne 0 ;then

fi


# 2. 编辑 /etc/chrony.conf
# 3. 去掉所有的 server开头的, 并加上 server cn.pool.ntp.org iburst prefer
firewall-cmd --add-service=ntp --permanent && firewall-cmd --reload
systemctl enable chronyd.service
systemctl stop chronyd.service
systemctl start chronyd.service

chronyc sources

timedatectl