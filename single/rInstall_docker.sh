#!/usr/bin/env bash
################################################################################
## Name: 全新环境使用yum安装最新的docker
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统的纯净环境
## 
################################################################################

ERR_CODE_MISS_PARAM=1
ERR_CODE_RUNTIME_FAIL=2

# info级别的日志 (String:msg) -> []
F_log_info(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[32m[Info] $* \033[0m"
  fi
}

# 防火墙放行端口 (String:port)
F_permit_port(){
  local _port=$1
  if [[ x"${_port}" != x"" ]]; then
    firewall-cmd --query-port="${_port}" > /dev/null || \
    ( firewall-cmd --add-port="${_port}" --permanent > /dev/null; \
    firewall-cmd --reload > /dev/null )
    return $?;
  fi
  echo ERR_CODE_MISS_PARAM
  return ${ERR_CODE_MISS_PARAM};
}

# 遇见非预期的错误则退出执行并显示错误文本，否则显示正常的文本 (int:命令执行的返回值, String: 错误提示信息, String:成功的显示文本) -> []
F_exit_unexpected(){
  local _return_code=${1:-0}
  if test ! "${_return_code}" -eq 0; then
    shift 1
    F_log_err "${1:-""}"
    exit "${_return_code}"
  else
    shift 2
    F_log_info "${1:-""}"
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
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

F_log_info "[3] 安装指定版本的docker"

sudo yum install -y docker-ce-20.10.21-3.el7 docker-ce-cli-20.10.21-3.el7 containerd.io-1.6.10-3.1.el7
F_exit_unexpected $? "安装失败"

F_log_info "[4] 修改docker镜像地址"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "data-root": "/opt/docker-data",
  "storage-driver": "overlay2",
  "registry-mirrors":
  [
      "http://hub-mirror.c.163.com"
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
sudo systemctl restart docker
set +e
F_permit_port 2375/tcp
F_exit_unexpected $? "---> 防火墙放行端口2375失败"

# 确认启动成功
sudo docker run hello-world && docker rm -f $(docker container ls -a | grep "hello-world" | awk '{print $1}') > /dev/null 2>&1
F_exit_unexpected $? "启动失败" "启动成功"

curl http://localhost:2375/version
F_exit_unexpected $? " --> 远程控制异常" " --> 远程控制正常" 