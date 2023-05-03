#!/usr/bin/env bash
################################################################################
## Name: docker 部署一个单实例RabbitMQ
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
## 
## 1. 自定义节点名，容器名
## 2. 自定义用户，密码
## 3. 自定义vHost
## 4. 默认开启Web管理界面 
## 5. 默认随docker进程的启动而启动
## 6. 默认暴露端口 5672，15672
## 7. 提示用户选择是否安装插件，默认安装
##
################################################################################

ERR_CODE_MISS_PARAM=1
DOCKER_CONTAINER_NAME=test-rabbitmq
R_HOST_NAME=rabbit-test-1
R_PORT=5672
R_WEB_PORT=15672
R_USER=admin
R_PASSWORD=Admin.123
R_VHOST=test

F_docker_run_command(){
  set -x
  docker run -d --restart=always \
    --hostname ${R_HOST_NAME} --name ${DOCKER_CONTAINER_NAME} \
    -p ${R_PORT}:5672 -p ${R_WEB_PORT}:15672 \
    -e RABBITMQ_DEFAULT_USER=${R_USER} \
    -e RABBITMQ_DEFAULT_PASS=${R_PASSWORD} \
    -e RABBITMQ_DEFAULT_VHOST=${R_VHOST} \
    rabbitmq:3-management
  set +x
}

F_loop_permit_port(){
  F_permit_port ${R_PORT}/tcp && \
  F_permit_port ${R_WEB_PORT}/tcp
}

# info级别的日志 (String:msg)
F_log_info(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[32m[Info] $* \033[0m"
  fi
}

# warn级别或是需要引起用户重视的日志 (String:msg)
F_log_note(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\033[33m[Note] $* \033[0m"
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

# 安装插件 delayed_message_exchange
F_install_rabbitmq_delayed_message_exchange(){
  local file=rabbitmq_delayed_message_exchange-3.11.1.ez
  local plug_url=https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/3.11.1/rabbitmq_delayed_message_exchange-3.11.1.ez
  curl -JLO ${plug_url}
  F_exit_unexpected $? "下载插件失败,路径:${plug_url}"
  docker cp ${file} ${DOCKER_CONTAINER_NAME}:/plugins && \
  docker exec ${DOCKER_CONTAINER_NAME} sh -c \
  "rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange"
  F_exit_unexpected $? " ---> 安装插件 [delayed_message_exchange] 失败"
  test -e ${file} && rm ${file}
}

#---------------------------------------------------------------------------------------------------
#main

if [[ x"-i" = x"${1}" ]]; then
  unset _value_
  read -p "Docker容器名, 默认 ${DOCKER_CONTAINER_NAME}: " _value_
  DOCKER_CONTAINER_NAME=${_value_:-${DOCKER_CONTAINER_NAME}}

  unset _value_
  read -p "RabbitMQ 密码，默认 ${R_PASSWORD}: " _value_
  R_PASSWORD=${_value_:-${R_PASSWORD}}

  unset _value_
  read -p "RabbitMQ 端口，默认 ${R_PORT}: " _value_
  R_PORT=${_value_:-${R_PORT}}

  unset _value_
  read -p "RabbitMQ Web 端口，默认 ${R_WEB_PORT}: " _value_
  R_WEB_PORT=${_value_:-${R_WEB_PORT}}

  unset _value_
  read -p "RabbitMQ HOST, 默认 ${R_HOST_NAME}: " _value_
  R_HOST_NAME=${_value_:-${R_HOST_NAME}}

  unset _value_
fi

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

F_log_info "[4] 插件选择.."
F_log_note " --> 是否安装插件: [rabbitmq_delayed_message_exchange-3.11.1]"
_option_=y
read -t 5 -p "[y/n]默认安装:y" -n 1 _option_

if [[ x"${_option_}"=x"y" ]]; then
  F_install_rabbitmq_delayed_message_exchange
fi

F_log_info "[5] 重启容器.."

docker restart ${DOCKER_CONTAINER_NAME} && F_log_info " ---> 重启成功" || F_log_err " ---> 重启失败"