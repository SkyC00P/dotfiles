#!/usr/bin/env bash
################################################################################
## Name: 函数库
## Author:  skycoop
## Version: 1.0
## 
################################################################################

if [[ x"$*" != x"" ]];then
  export PS4='+($(date "+%Y-%m-%d %H:%M:%S") - ${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi

CODE_ERR_MISS_PARAM=1001
CODE_SUC=0

# info级别的日志 (String:msg) -> []
F_log_info(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[32m[Info] $* \033[0m"
  fi
}

# warn级别或是需要引起用户重视的日志 (String:msg) -> []
F_log_note(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\033[33m[Note] $* \033[0m"
  fi
}

# error级别的日志 (String:msg) -> []
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

# 删除指定镜像名的所有容器
# $1 = (String:msg) = docker镜像名
F_docker_rm_container_by_image(){
  
  local imageName=$1
  local rm_list=

  if [[ x"${imageName}" != x"" ]];then

    for line in $(docker ps -aq --no-trunc  --filter ancestor="${imageName}")
    do
      docker rm -f "${line}"
      if [[ $? -ne 0 ]]; then
        return 1
      fi
    done
    return 0
  else
    echo CODE_ERR_MISS_PARAM
    return 1
  fi
  
}

# 关闭SELinux
# 
F_config_SELinux(){
  local param=${1:-0}
  if [[ x"${param}" = x"" ]];then
    # 永久关闭
    setenforce 0
    sed -i "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config
  else
    # 临时关闭
    setenforce ${param}
  fi
}
