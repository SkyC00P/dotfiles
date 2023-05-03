#!/usr/bin/env bash
################################################################################
## Name: docker 部署一个单实例 Redis
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
## 
## 1. 指定镜像: redis:7, 默认容器名 test-redis
## 2. 默认无用户名和密码
## 3. 不做持久化
## 4. 开机自启动
## 5. 默认端口 6379 并暴露
##
################################################################################

ERR_CODE_MISS_PARAM=1
DOCKER_CONTAINER_NAME=test-redis

F_docker_run_command(){
  docker run -d --name ${DOCKER_CONTAINER_NAME} -p 6379:6379 --restart=always redis:7
}

F_loop_permit_port(){
  F_permit_port 6379/tcp
}

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

F_log_info "[1] 检查Docker环境"
systemctl status docker > /dev/null 2>&1
F_exit_unexpected $? "---> docker 环境异常" "---> Pass"

F_log_info "[2] 启动Docker镜像"
docker ps -a | grep -E "(^| )${DOCKER_CONTAINER_NAME}( |$)"
if test $? -eq 0; then
  F_log_err "当前Docker已经存在对应名的容器:${DOCKER_CONTAINER_NAME}, 无法再次安装"
  exit 1
fi

F_docker_run_command
F_exit_unexpected $? "启动Docker镜像失败"

F_log_info "[3] 防火墙放行端口"

systemctl status firewalld > /dev/null 2>&1

_firewalld_status_=$?

F_log_info "---> firewalld 防火墙状态为:${_firewalld_status_}"

if test ${_firewalld_status_} -eq 0; then
  F_loop_permit_port
  F_log_info "防火墙放行端口执行结果:$?"
fi