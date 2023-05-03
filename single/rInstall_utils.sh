#!/usr/bin/env bash
################################################################################
## Name: 常用的工具
## Author:  skycoop
## Version: 1.0
## 
## 仅适用于CentOS7系统
################################################################################

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
  return 1;
}

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

# error级别的日志 (String:msg)
F_log_err(){
  local _msg="$1"
  if [[ x"${_msg}" != x"" ]];then
    echo -e "\a\033[31m[Err] $* \033[0m"
  fi
}

F_show_list(){

  cat <<EOF

0. 退出
1. ShellCheck -> shell 的语法检查工具
2. tree -> 树形目录结构查看工具
3. samba -> 文件共享
EOF

}

F_install_shellcheck(){
  F_log_info " ---> ready install shellcheck..."
  sudo yum -y install epel-release
  sudo yum install -y ShellCheck
}

F_install_tree(){
  F_log_info " ---> ready install tree..."
  sudo yum -y install tree
}

F_install_samba(){
  F_log_info " ---> ready install samba..."
  sudo yum -y install samba

  if test $? -ne 0; then
    F_log_err " ---> samba 安装失败"
    return 1
  fi

  read -t 5 -p $'\n---> 是否使用默认的samba用户名root和密码123456, [y/n]:' -n 1 _option_

  _option_=${_option_:-y}
  if [[ x"${_option_}" != x"y" ]]; then
    read -p $'\n---> 请输入用户名,不填则默认为root, 回车确定:' samba_user
    read -p $'\n---> 请输入密码,不填则默认为123456, 回车确定:' -s samba_password    
  fi

  echo -e "\n"
  samba_user=${samba_user:-root}
  samba_password=${samba_password:-123456}

  (echo "${samba_password}"; echo "${samba_password}") | sudo smbpasswd -s -a "${samba_user}"
  if test $? -eq 0; then
    F_log_info "samba 新增用户 ${samba_user} 成功"
  else
    F_log_err "samba 新增用户 ${samba_user} 失败"
    return 1
  fi

  id -u "${samba_user}" > /dev/null 2>&1
  if test $? -ne 0; then
    F_log_err " ---> 当前Linux不存在名为[${samba_user}]的用户"
    return 1
  fi

  grep -x "[${samba_user}]" /etc/samba/smb.conf > /dev/null 2>&1
  if test $? -eq 0; then
    F_log_note " ---> 配置文件[/etc/samba/smb.conf]已存在相同的用户共享配置"
    return 1
  else
    F_log_info " ---> 配置[${samba_user}]的共享选项"
    cat >> /etc/samba/smb.conf \
<<EOF

[${samba_user}]
	comment = ${samba_user} linux 共享
	path = /
	public = yes
	writable = yes
	browseable = yes
	available = yes
EOF

  fi

  testparm -s > /dev/null
  if test $? -ne 0; then
    F_log_err " ---> 配置文件[/etc/samba/smb.conf]语法检测异常，请检查"
    return 1
  fi

  F_permit_port 445/tcp && F_permit_port 139/tcp
  F_log_info " ---> 防火墙放行端口445和139,结果:$?"
  
  setenforce 0
  sudo sh -c 'cat > /etc/selinux/config <<"EOF"
  SELINUX=disabled
  SELINUXTYPE=targeted
  EOF'
  sudo service smb restart >/dev/null 2>&1
  F_log_info " ---> 文件共享工具 samba 重启:$?"
  sudo chkconfig smb on >/dev/null 2>&1
  F_log_info " ---> 文件共享工具 samba 开机自启:$?"
  F_log_info " ---> samba 安装结束"
}

Option=

F_next_step(){
  F_log_note "[USER] 请选择下一步"
  F_show_list
  read -p "选择的序号[id], Ctrl+C 强制退出: " Option
  F_install ${Option}
  F_next_step
}

F_install(){
  local _option=$1
  if [[ x"${_option}" != x"" ]];then
    case "${_option}" in
      "1") F_install_shellcheck;;
      "2") F_install_tree;;
      "3") F_install_samba;;
      "0") exit 0;;
      *) F_log_err "---> 无效选项";exit 1;;
    esac
  fi
}

F_log_note "[USER] 请选择需安装的工具"
F_show_list
read -p "选择的序号或退出[id/n], Ctrl+C强制退出, 回车确认: " Option
F_install ${Option}
F_next_step