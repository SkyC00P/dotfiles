#!/usr/bin/env bash
################################################################################
## Name: docker node 编译Vue项目
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
## 1. 选择版本 19.1.0
################################################################################

# error级别的日志 (String:msg)
F_log_err(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[31m[Err] $* \033[0m"
  fi
}

SRC_DIR=${1}

if[[ x"${SRC_DIR}" = "" ]]; then
  F_log_err "Node 项目路径为空"
  exit 1
fi

set -x
docker run -it --rm --name build-node-1 -v "$SRC_DIR":/usr/src/app -w /usr/src/app node:19.1.0  -c sh -c "npm install && npm run build "
set +x
