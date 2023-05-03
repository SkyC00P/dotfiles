#!/usr/bin/env bash
################################################################################
## Name: git clone 当前项目
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统的纯净环境
##
##  
################################################################################

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

F_check_git(){
    git --version >/dev/null 2>&1
}

F_install_git(){
    sudo yum install -y git
}

F_check_git || F_install_git

F_check_git
F_exit_unexpected $? " ---> 未检测到可用的git命令行"

_git_remote_type_=${GIT_REMOTE_TYPE:-private}

if [[ x"private" = x"${_git_remote_type_}" ]]; then
  _clone_url_=http://192.168.0.55/devops/centos7-runtime-env.git
else
  _clone_url_=https://github.com/SkyC00P/dotfiles.git
fi

git clone ${_clone_url_}