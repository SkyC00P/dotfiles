#!/usr/bin/env bash
################################################################################
## Name: docker 部署单实例MySQL
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
## 1. 自定义选择MySQL版本 5.7 还是 8，默认8
## 2. 自定义是否创建新用户，默认不创建
## 3. 自定义超管root密码
## 4. 开启远程客户端连接
## 5. 自定义数据存储方式
## 6. 修改默认的MySQL配置
## 7. 开机随docker启动而启动
## 8. 自定义端口并且防火墙放行
## 9. 自定义容器名 test-mysql-$version
##
################################################################################

MYSQL_VERSION=
MYSQL_USER=
MYSQL_USER_PASSWORD=
MYSQL_ROOT_PASSWORD=
MYSQL_PORT=
MYSQL_VOLUME_COMMAND=

DOCKER_CONTAINER_NAME=

F_docker_run_command(){

  local user_command=

  if [[ x"${MYSQL_USER}" != x"" ]]; then
    user_command="-e MYSQL_USER=${MYSQL_USER} -e MYSQL_PASSWORD=${MYSQL_USER_PASSWORD}"
  fi

  # 判断当前是否已存在同名的容器
  if [[ x"${DOCKER_CONTAINER_NAME}" = x"" ]]; then
    F_log_err " ---> 容器名不能为空"
    return 1;
  fi
  
  local name=$(docker ps -a --format "{{.Names}}" --filter name="^/${DOCKER_CONTAINER_NAME}$")

  if [[ x"${name}" != x"" ]]; then
    F_log_err " ---> 存在同名的容器:${name}"
    return 1;
  fi

  set -x
  docker run -d --restart=always \
    --name ${DOCKER_CONTAINER_NAME} \
    -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}\
    ${user_command} \
    ${MYSQL_VOLUME_COMMAND}\
    -p ${MYSQL_PORT:-3306}:3306 \
    mysql:${MYSQL_VERSION:-8} \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci
  local status=$?
  set +x
  return $status
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
  systemctl status firewalld.service > /dev/null 2>&1
  if test $? -ne 0; then
    F_log_note " ---> 防火墙未运行"
    return 0
  fi

  local _port=$1

  if [[ x"${_port}" != x"" ]]; then
    firewall-cmd --query-port="${_port}" > /dev/null || \
    ( firewall-cmd --add-port="${_port}" --permanent > /dev/null; \
    firewall-cmd --reload > /dev/null )
    return $?;
  fi
  echo ERR_CODE_MISS_PARAM
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

Enter(){
  echo ""
}

F_read_config(){
  # 是否配置MySQL
  local option=
  local user=
  local pwd=
  local root_pwd=
  local port=
  local name=

  read -p $'\n---> 配置MySQL版本\n [1]:5.7\n [2]:8\n\n请输入序号，默认[2]: ' -n 1 option
  Enter
  if [[ x"${option}" = x"1" ]]; then
    MYSQL_VERSION=5.7
    DOCKER_CONTAINER_NAME=test-mysql-${MYSQL_VERSION}
  else
    MYSQL_VERSION=8
    DOCKER_CONTAINER_NAME=test-mysql-${MYSQL_VERSION}
  fi

  # 是否创建自定义用户
  read -p '---> 是否创建自定义用户,要创建输入 y: ' -n 1 option
  Enter
  if [[ x"${option}" = x"y" ]]; then
    read -p $'---> 用户名,默认skycoop, 回车确认:' user
    Enter
    MYSQL_USER=${user:-skycoop}
    read -p $'---> 密码,默认123456, 密码输入无显示, 回车确认: ' -s pwd
    Enter
    MYSQL_USER_PASSWORD=${pwd:-123456}
  fi

  # 配置超管密码
  read -p $'---> 是否配置root用户密码，默认123456，要更改输入 y: ' -n 1 option
  Enter
  if [[ x"${option}" = x"y" ]]; then
    read -p $'---> root用户密码,默认123456, 回车确认: ' -s root_pwd
    Enter
    MYSQL_ROOT_PASSWORD=${root_pwd:-123456}
  else
    MYSQL_ROOT_PASSWORD=123456
  fi

  # 配置端口
  read -p $'---> 是否配置端口，默认3306，要更改输入 y: ' -n 1 option
  Enter
  if [[ x"${option}" = x"y" ]]; then
    read -p $'---> 配置端口,默认3306, 回车确认: ' port
    Enter
    MYSQL_PORT=${port:-3306}
  else
    MYSQL_PORT=${MYSQL_PORT:-3306}
  fi

  # 配置容器名
  read -p $"---> 是否配置容器名,当前名：${DOCKER_CONTAINER_NAME},默认不配置, 配置输入y: " -n 1 option
  Enter
  if [[ x"${option}" = x"y" ]]; then
    read -p $'\n---> 配置容器名 回车确认: ' name
    Enter
    DOCKER_CONTAINER_NAME=${name:-${DOCKER_CONTAINER_NAME}}
  fi

}

F_set_store_host_mount(){
  local dir=$1
  if [[ x"${dir}" = x"" ]]; then
    F_log_note " ---> 请输入数据保存的目录"
    read -p "回车确认: " dir
    Enter
  fi

  mkdir -p ${dir} > /dev/null 2>&1
  F_exit_unexpected $? " ---> [F_set_store_host_mount] 创建目录 ${dir} 失败"

  if [[ -e "${dir}" && x$(ls -A ${dir}) = x"" ]]; then
    MYSQL_VOLUME_COMMAND="-v ${dir}:/var/lib/mysql"
  else
    F_log_note " ---> 警告，您选择了非空的目录[${dir}], 请确定是否是原来旧的MySQL数据目录。不同版本之间的MySQL数据目录无法混用，且同时仅能有一个数据库实例访问"
    local option=
    read -p "默认不复用n, 复用请输入 y: " -n 1 option
    Enter
    
    option=${option:-n}
    if [[ x"$option" = x"n" ]]; then
      read -p "请输入新的目录, 回车确认:" dir
      Enter
      F_set_store_host_mount ${dir}
      return $?
    else
      MYSQL_VOLUME_COMMAND="-v ${dir}:/var/lib/mysql"
    fi

  fi

}

F_set_store_share_volume(){
  local dir=$1
  if [[ x"$dir" = x"" || "$dir" == */* ]]; then
    F_log_note " ---> 数据卷名不能为空或者包含/，请重新选择"
    read -p "回车确认" dir
    Enter
    F_set_store_share_volume $dir
    return $?
  fi

  docker volume ls --format "{{.Name}}" | grep -E "^${dir}$" > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    F_log_note " ---> 存在同名的数据卷${dir},是否复用"
    F_log_note "[WARN] ---> 不同MYSQL实例无法同时共用一个MYSQL数据目录，不同版本之间的MySQL数据目录无法混用， 请确定是否是原来旧的MySQL数据目录且旧的容器没有在运行。"
    read -n 1 -p "默认不复用n [y/n]:" option
    Enter
    option=${option:-n}

    if [[ x"${option}" != x"y" ]]; then
      F_log_info "当前已存在的数据卷"
      docker volume ls --format "{{.Name}}"
      read -p "输入数据卷名, 回车确认: " dir
      Enter
      F_set_store_share_volume $dir
      return $?
    fi

  fi

  MYSQL_VOLUME_COMMAND="-v ${dir}:/var/lib/mysql"
}

F_set_store() {
  F_log_info " ---> 当前默认的存储配置如下"
  cat <<-EOF

    当前默认存储模式: [1]宿主机本地挂载
    支持的模式: [1] 宿主机本地挂载 [2] Docker数据卷Volume共享 [3] 容器内部存储

    [1]宿主机本地挂载
    默认会在宿主机新建一个空目录:/opt/mysql/{version}/data
    MySQL数据 /var/lib/mysql 保存在该宿主机目录下
    如果该目录不是空目录，则提示是否重新选择一个新的目录

    [2]Docker数据卷Volume共享
    默认会新建名为  mysql-data-{MYSQL_VERSION} 的Docker数据卷并进行关联
    MySQL数据 /var/lib/mysql 保存在该Docker数据卷下
    如果存在同名数据卷，则提示是否重新共用此数据卷

    [3]容器内部存储
    数据保存在容器内部，与[1],[2]不同的是，删除容器时其数据也随之删除


EOF

  local option=
  read -p $'---> 是否修改当前配置[y/n]，默认不修改, 修改输入 n: ' -n 1 option
  Enter
  option=${option:-y}

  if [[ x"${option}" == x"y" ]]; then
    F_set_store_host_mount /opt/mysql/${MYSQL_VERSION}/data
  else
    read -p "---> 请选择重新配置的模式[1/2/3]" -n 1 option
    Enter
    case ${option:-0} in
    1)
      F_set_store_host_mount
      ;;
    2)
      F_set_store_share_volume mysql-data-${MYSQL_VERSION}
      ;;
    3)
      MYSQL_VOLUME_COMMAND=
      ;;
    *) F_exit_unexpected 1 " ---> 未知选项" ;;
    esac
  fi

}

F_open_remote_conn(){

  if [[ x"${MYSQL_USER}" != x"" ]]; then
    local user_command_1="alter user '${MYSQL_USER}'@'%' identified with mysql_native_password by '${MYSQL_USER_PASSWORD}';"
    local user_command_2="GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;"
  fi

  for i in {1..5}
  do
    docker exec -i ${DOCKER_CONTAINER_NAME} sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' >/dev/null 2>&1 <<-EOF
      alter user 'root'@'%' identified with mysql_native_password by '${MYSQL_ROOT_PASSWORD:-123456}';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
      ${user_command_1};
      ${user_command_2};
      flush privileges;
EOF

  if [[ "$?" -eq 0 ]]; then
    F_log_info " ---> ${DOCKER_CONTAINER_NAME} 开启远程连接成功"
    return 0
  else
    F_log_note " ---> MySQL尚未启动完成，等待60s继续尝试，已尝试 $i 次"
    sleep 60
  fi

  done
  return 1
}

#---------------------------------------------------------------------------------------------------
#main

F_log_info "[1] 检查Docker环境"
systemctl status docker > /dev/null 2>&1
F_exit_unexpected $? "---> docker 环境异常" "---> Pass"

F_log_info "[2] 配置参数"
F_read_config

F_log_info "[3] 配置MySQL存储方式"
F_set_store

F_log_info "[4] 启动容器"
F_docker_run_command
F_exit_unexpected $? " ---> 启动新容器失败"

F_log_info "[5] 配置参数"
set -x
docker exec ${DOCKER_CONTAINER_NAME} sh -c "
echo [mysqld] > /etc/mysql/conf.d/local.cnf;
echo lower_case_table_names=1 >> /etc/mysql/conf.d/local.cnf;
echo default-time-zone='+08:00' >> /etc/mysql/conf.d/local.cnf;
"
set +x

F_exit_unexpected $? " ---> 配置参数失败"

F_log_info "[6] 开启root远程客户端连接"

if [[ x"${MYSQL_VERSION}" = x"8" ]]; then
  F_open_remote_conn
  F_exit_unexpected $? " ---> 开启root远程客户端连接失败"
else
  F_log_info " ---> ${MYSQL_VERSION} 默认已开启远程客户端连接"
fi

F_log_info "[7] 放行端口"
F_permit_port ${MYSQL_PORT}/tcp

F_log_info " --- Docker 实例化结束"