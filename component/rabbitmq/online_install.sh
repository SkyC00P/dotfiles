#!/usr/bin/env bash
################################################################################
## Name: docker 部署一个单实例RabbitMQ
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统
## 
## 1. 自定义节点名 rabbit-test-1， 容器名 rabbit-test
## 2. 自定义用户 skycoop，密码 #dev5207End
## 3. 自定义vHost skycoop-test
## 4. 开启Web管理界面 
## 5. 开机自启动
## 
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

F_log_info "[1] 检查Docker环境"

docker run hello-world > /dev/null 2>&1 && F_log_info "---> Pass" || Func_log_err "docker 环境异常"

F_log_info "[2] 启动Docker RabbitMQ镜像"

docker run -d --rm --restart=always \
  --hostname rabbit-test-1 --name rabbit-test \
  -p 5672:5672 -p 15672:15672 rabbitmq:3 \
  -e RABBITMQ_DEFAULT_USER='skycoop' \
  -e RABBITMQ_DEFAULT_PASS='#dev5207End' \
  -e RABBITMQ_DEFAULT_VHOST='skycoop-test'

$? && F_log_info "启动Docker RabbitMQ镜像成功" || Func_log_err "启动Docker RabbitMQ镜像失败"