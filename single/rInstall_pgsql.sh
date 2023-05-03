#!/usr/bin/env bash
################################################################################
## Name: docker 部署一个PgSQL数据库
## Author:  skycoop
## Version: 1.0
##
## 版本: 15.0
## 
## 1. 本地安装
## 2. 镜像安装 - 默认
##
################################################################################

DOCKER_CONTAINER_NAME=test-pgsql
POSTGRES_PASSWORD=Zlkjgz.123
POSTGRES_USER=zlkjgz

# info级别的日志 (String:msg)
F_log_info(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[32m[Info] $* \033[0m"
  fi
}

# error级别的日志 (String:msg)
F_log_err(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[31m[Err] $* \033[0m"
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
  return 1;
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

# 本地安装
F_local_install(){
  # Install the repository RPM:
  sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

  # Install PostgreSQL:
  sudo yum install -y postgresql15-server

  # Optionally initialize the database and enable automatic start:
  sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
  sudo systemctl enable postgresql-15
  sudo systemctl start postgresql-15
}

# docker 安装
F_docker_install(){
  F_log_info "[1] 检查Docker环境"
  systemctl status docker > /dev/null 2>&1
  F_exit_unexpected $? "---> docker 环境异常" "---> Pass"
  
  docker ps -a | grep -E "(^| )${DOCKER_CONTAINER_NAME}( |$)"
  if test $? -eq 0; then
    F_log_err "当前Docker已经存在对应名的容器:${DOCKER_CONTAINER_NAME}, 无法再次安装"
    exit 1
  fi

  F_docker_run_command
  F_exit_unexpected $? "启动Docker镜像失败"
  
}

F_docker_run_command(){
  # docker run --name test-pgsql -e POSTGRES_PASSWORD=Gzzlkj.123 -e POSTGRES_USER=gzzlkj --network=host -d --restart=always postgres:15.2
  # todo Pgsql 数据库的字符集, 字符编码问题, 时区问题 Collation Support
  set -x
  docker run --name ${DOCKER_CONTAINER_NAME} \
  -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
  -e POSTGRES_USER=${POSTGRES_USER} \
  --network=host -d --restart=always postgres:15.2
  set +x
}

which_run=${1:-docker}

if [[ x"${which_run}" = x"docker" ]];then
  F_docker_install
else
  F_local_install
fi