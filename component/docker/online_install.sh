#!/usr/bin/env bash
################################################################################
## Name: 全新环境使用yum安装最新的docker
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统的纯净环境
## 
################################################################################

# info级别的日志 (String:msg) -> []
F_log_info(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[32m[Info] $* \033[0m"
  fi
}

# error级别的日志 (String:msg) -> []
Func_log_err(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[31m[Err] $* \033[0m"
  fi
}

F_log_info "[1] 移除旧的docker"
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

F_log_info "[2] 添加Yum仓库映射" 
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

F_log_info "[3] 安装最新的docker"
sudo yum install -y docker-ce docker-ce-cli containerd.io

F_log_info "[4] 修改docker镜像地址"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "data-root": "/home/docker-data",
  "storage-driver": "overlay2",
  "registry-mirrors":
  [
      "https://docker.mirrors.ustc.edu.cn",
      "http://hub-mirror.c.163.com",
      "https://7f5rcv6e.mirror.aliyuncs.com"
  ]
}
EOF

F_log_info "[5] 开启开机自启动"
sudo systemctl enable docker

F_log_info "[6] 开启远程控制"
key__='ExecStart';
value__='/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock';
path__='/lib/systemd/system/docker.service'
grep "tcp://0.0.0.0:2375" ${path__} || sed -i "s|${key__}=.*$|${key__}=${value__:-""}|g" ${path__};

F_log_info "[7] 启动docker并校验是否安装成功"
sudo systemctl daemon-reload
sudo systemctl start docker

# 确认启动成功
sudo docker run hello-world;
$? && F_log_info " --> 启动成功" || Func_log_err " --> 启动失败"

curl http://localhost:2375/version
$? && F_log_info " --> 远程控制正常" || Func_log_err " --> 远程控制异常"