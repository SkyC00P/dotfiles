#!/usr/bin/env bash
################################################################################
## Name: docker 部署一个支持事务的最小副本集集群
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
##
## 1. 指定镜像: mongo:6.0.2, 默认容器名 mongo-rs01, mongo-rs02, mongo-rs03
## 2. 随Docker的启动而启动
## 3. 自定义环境变量
##    MONGODB_ROOT_PATH mongodb   存储根目录，默认/opt/mongo-rs
##    SYS_OS_IP                   指定配置的IP，默认为读取的第一个网卡的有效地址
##    MONGO_INITDB_ROOT_USERNAME  初始化mongodb实例的用户名，默认admin
##    MONGO_INITDB_ROOT_PASSWORD  初始化mongodb实例的密码，默认jbkj@123
## 4. 3节点共用密钥文件 key/mongo-rs.key
## 5. 3节点使用端口 30011 - 30013, 防火墙放行端口
## 6. 默认第1，2节点作为副本节点，第3节点做裁决节点
##
################################################################################

_MONGODB_ROOT_PATH_=${MONGODB_ROOT_PATH:-/opt/mongo-rs}
_IP_=${SYS_OS_IP}
_USER_=${MONGO_INITDB_ROOT_USERNAME:-admin}
_PASSWORD_=${MONGO_INITDB_ROOT_PASSWORD:-jbkj@123}

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

# 防火墙放行端口 (String:port)
F_permit_port(){
  local _port=$1
  local _code=1
  if [[ x"${_port}" != x"" ]]; then
    firewall-cmd --query-port="${_port}" > /dev/null || \
    ( firewall-cmd --add-port="${_port}" --permanent > /dev/null; \
    firewall-cmd --reload > /dev/null )
    _code=${?}
  fi
  return ${_code};
}

# --------------------------------------------------------------------------------------------------
# main method

F_log_info "[1] 检查Docker环境"
systemctl status docker > /dev/null 2>&1
F_exit_unexpected $? "---> docker 环境异常" "---> Pass"

F_log_info "[2] 创建mongodb根目录"

mkdir -p ${_MONGODB_ROOT_PATH_}/{data01,data02,data03,key,backup}
F_exit_unexpected $? "--> 创建mongodb根目录失败"

ls -l ${_MONGODB_ROOT_PATH_}

F_log_info "[3] 创建密钥"

if test ! -e "${_MONGODB_ROOT_PATH_}/key/mongo-rs.key"; then
  openssl rand -base64 756 > ${_MONGODB_ROOT_PATH_}/key/mongo-rs.key &&\
  chmod 400 ${_MONGODB_ROOT_PATH_}/key/mongo-rs.key &&\
  chown polkitd:input ${_MONGODB_ROOT_PATH_}/key/mongo-rs.key
  F_exit_unexpected $? "--> 创建密钥失败"
else
  F_log_info "密钥已存在，不重复创建"
fi

ls -l ${_MONGODB_ROOT_PATH_}/key/mongo-rs.key

F_log_info "[4] 创建mongodb三节点"

F_docker_create_node(){
  local node_num=$1
  local port=$(expr 30010 + $node_num)
  local name=mongo-rs0${node_num}
  local data_dir_name=data0${node_num}

  F_log_info "---> 准备第${node_num}个Mongodb副本节点，端口号:${port}, 容器名:${name}, 存储目录:${data_dir_name}"
  docker run --restart=always --name ${name} \
    -p ${port}:27017 \
    -v ${_MONGODB_ROOT_PATH_}/${data_dir_name}:/data/db \
    -v ${_MONGODB_ROOT_PATH_}/backup:/data/backup \
    -v ${_MONGODB_ROOT_PATH_}/key:/data/key \
    -v /etc/localtime:/etc/localtime \
    -e MONGO_INITDB_ROOT_USERNAME=${_USER_} \
    -e MONGO_INITDB_ROOT_PASSWORD=${_PASSWORD_} \
    -d mongo:6.0.2 --replSet mongo-rs --auth --keyFile /data/key/mongo-rs.key --bind_ip_all
  F_exit_unexpected $? "---> 创建Mongodb节点[${node_num}]docker容器失败"
  F_permit_port ${port}/tcp
}

F_docker_create_node 1
F_docker_create_node 2
F_docker_create_node 3

F_log_info "[5] 配置副本集"
sleep 10

if [[ x"${_IP_}" = x"" ]]; then
  _IP_=$(ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1)
fi

if [[ x"${_IP_}" = x"" ]]; then
  F_log_err "---> 当前IP配置为空"
  exit 1
fi

F_log_info "---> 当前配置的IP为:${_IP_}"

cat > /var/config.js <<EOF
use admin
db.auth("${_USER_}","${_PASSWORD_}")

var config={
     _id:"mongo-rs",
     members:[
         {_id:0,host:"${_IP_}:30011"},
         {_id:1,host:"${_IP_}:30012"},
		     {_id:2,host:"${_IP_}:30013",arbiterOnly:true}
]};
rs.initiate(config)
rs.status()
EOF

docker cp /var/config.js mongo-rs01:/var/config.js &&\
docker exec mongo-rs01 sh -c "mongosh < /var/config.js" &&\
test -e /var/config.js && rm /var/config.js

F_exit_unexpected $? "---> 配置副本集失败"
