#!/usr/bin/env bash
################################################################################
## Name: 全docker 部署一个单实例 FTP 服务器
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统的纯净环境
## 
################################################################################

FTP_ROOT=/opt/vsftpd
FTP_USER=jbgf
FTP_PASS="jbkj*&)706"
_IP_=${SYS_OS_IP}

mkdir -p ${FTP_ROOT}

if [[ x"${_IP_}" = x"" ]]; then
  _IP_=$(ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1)
fi

docker run --restart=always -d -v ${FTP_ROOT}:/home/vsftpd \
-p 20:20 -p 21:21 -p 21100-21110:21100-21110 \
-e PASV_ADDRESS=${_IP_} \
-e FTP_USER=${FTP_USER} -e FTP_PASS=${FTP_PASS} --name vsftpd fauria/vsftpd
