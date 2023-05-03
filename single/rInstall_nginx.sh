#!/usr/bin/env bash
################################################################################
## Name: docker 部署单实例Nginx
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
## 1. 选择版本 1.23.2
## 2. 自定义暴露的接口并防火墙放行
## 3. 自定义挂载的项目路径
################################################################################

NGINX_ROOT_DIR=/opt/nginx
NGINX_VERSION=1.23.2
NGINX_VOLUME_COMMAND=
NGINX_NET_COMMAND=
NGINX_TMP_CONFIG_FILE=/tmp/default.conf
NGINX_TMP_CONTAINER_NAME=tmp-nginx-$RANDOM

declare -A NGINX_CONFIG_ARR_STATIC=()
declare -A NGINX_CONFIG_ARR_WEB=()
declare -A NGINX_CONFIG_ARR_PROXY_API=()
NGINX_CONFIG_VAR_PORT=
NGINX_CONFIG_VAR_BODY_SIZE=

DOCKER_CONTAINER_NAME=test-nginx

F_docker_run_command(){

  if [[ x"${DOCKER_CONTAINER_NAME}" = x"" ]]; then
    F_log_err " ---> 容器名不能为空"
    return 1;
  fi

  # 判断当前是否已存在同名的容器
  local name=$(docker ps -a --format "{{.Names}}" --filter name="^/${DOCKER_CONTAINER_NAME}$")

  if [[ x"${name}" != x"" ]]; then
    F_log_err " ---> 存在同名的容器:${name}"
    return 1;
  fi

  set -x
  docker run -d --restart=always \
    --name ${DOCKER_CONTAINER_NAME} \
    ${NGINX_VOLUME_COMMAND}\
    ${NGINX_NET_COMMAND} \
    nginx:${NGINX_VERSION} 
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

F_is_repeat_container_name(){
  local name=$1
  if [[ x"${name}" = x"" ]]; then
    echo "非法容器名"
    return 1;
  fi

  name=$(docker ps -a --format "{{.Names}}" --filter name="^/${name}$")

  if [[ x"${name}" != x"" ]]; then
    echo "存在"
    return 1;
  else
    echo "不存在"
    return 0;
  fi
}

# 1. 配置容器名
# 2. 配置Nginx挂载的根目录
F_set_config() {
  local options=("是" "否" "退出")
  local PS3="选择序号，回车确认:"
  local isReat=$(F_is_repeat_container_name ${DOCKER_CONTAINER_NAME})

  F_log_note "[USER]---> 当前默认容器名为:${DOCKER_CONTAINER_NAME}, 是否存在同名容器:${isReat}, 是否重新配置"

  select option in ${options[@]}; do
    case ${option} in
    "是")
      while true 
      do
        read -p "请输入新的容器名, 回车确认:" DOCKER_CONTAINER_NAME
        F_is_repeat_container_name ${DOCKER_CONTAINER_NAME} > /dev/null 2>&1
        if test $? -eq 0; then
          F_log_info " ---> 成功配置新的容器名:${DOCKER_CONTAINER_NAME}"
          break;
        else
          F_log_err " ---> 容器${DOCKER_CONTAINER_NAME}已经存在，请重新配置"
        fi
      done
      break
      ;;
    "否") break ;;
    "退出") exit 0 ;;
    esac
  done

  F_log_note "[USER]---> 当前Nginx挂载的根目录为${NGINX_ROOT_DIR}, 是否重新选择"
  echo "
  以此脚本启动的Nginx容器如需将内部的文件挂载到宿主机，则会在 {NGINX_ROOT_DIR} 以容器名新建目录，并将对应的文件或目录挂载到此目录下。

  如启动运行一个托管静态资源的Nginx容器 static-nginx, 其托管的静态资源文件 static 会保存在宿主机的 {NGINX_ROOT_DIR}/static-nginx/static
	"
  select option in ${options[@]}; do
    case ${option} in
    "是")
      while true 
      do
        read -p "请输入新的根目录, 回车确认:" NGINX_ROOT_DIR
        F_is_repeat_container_name ${DOCKER_CONTAINER_NAME} > /dev/null 2>&1
        if test $? -eq 0; then
          F_log_info " ---> 成功配置新的容器名:${DOCKER_CONTAINER_NAME}"
          break;
        else
          F_log_err " ---> 容器${DOCKER_CONTAINER_NAME}已经存在，请重新配置"
        fi
      done
      break
      ;;
    "否") break ;;
    "退出") exit 0 ;;
    esac
  done

}

F_build_cmd_set_port(){
  local port=
  read -p "Ctrl+D返回上一步, 输入Nginx监听的端口, 回车确认: " port
  
  if [[ $? -ne 0 ]]; then 
    return 1 
  fi

  if [[ $port =~ $is_Integer_re ]]; then
    F_log_info "您配置监听的端口为:${port}"
    NGINX_CONFIG_VAR_PORT=${port}
  else
    F_log_err "请输入有效的端口号"
    F_build_cmd_set_port
  fi
}

F_build_cmd_set_body_size(){
  local limit=
  read -p "Ctrl+D返回上一步, 输入要限制的文件大小，如100M, 则输入100，不限制则输入0 : " limit

  if [[ $? -ne 0 ]]; then 
    return 1 
  fi

  if [[ x"$limit" = x"0" ]]; then
    NGINX_CONFIG_VAR_BODY_SIZE="client_max_body_size 0;"
  elif [[ x"$limit" = x"" ]]; then
    NGINX_CONFIG_VAR_BODY_SIZE=
  elif [[ "${limit}" =~ $is_Integer_re ]]; then
    NGINX_CONFIG_VAR_BODY_SIZE="client_max_body_size ${limit}M;"
  else
    F_log_err "请输入有效的值"
    F_build_cmd_set_body_size
  fi
}

F_build_cmd_static(){
  F_log_info $'--> 注意，最终生成是以alias配置的,如下'
  
  cat <<EOF
  location /i/ {
    alias /data/w3/images/;
  }
EOF

  F_log_info "请求 /i/top.gif , 返回文件 /data/w3/images/top.gif "
  F_log_info "alias响应的路径：配置路径+静态文件(去除location中配置的路径)"

  local keepLoop=0
  local options=("新增" "修改" "删除" "查询" "清空" "查看所有" "返回")
  local PS3="[指令构建-静态资源] 请选择指令 => "
  while true 
  do
    echo
    F_log_info $'--> 请选择执行的指令'
    select option in ${options[@]}; do
      case $option in
        "新增")
          read -e -p "Key(location)=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_STATIC[${key}]}
          if [[ x"${value}" = x"" ]]; then
            read -e -p "Value(/download/{带/的你配置的路径})=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_STATIC["${key}"]="/download/${value}"
            fi
          else
            F_log_err " ${key} 已存在"
          fi
          break
        ;;
        "修改") 
          read -e -p "Key(location)=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_STATIC[${key}]}
          if [[ x"${value}" != x"" ]]; then
            read -e -p "Value(/download/{带/的你配置的路径})=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_STATIC["${key}"]="/download/${value}"
            fi
          else
            F_log_err " ${key} 不存在"
          fi
          break
        ;;
        "删除") 
          read -p "删除Key值(location)=> " -e key
          if [[ $? -eq 0 && x"${key}" != "" ]]; then
            unset NGINX_CONFIG_ARR_STATIC["${key}"]
          fi
          break
        ;;
        "查询")
          read -p "查询Key值(location)=> " -e key
          F_log_info "${key} : ${NGINX_CONFIG_ARR_STATIC[${key}]}"
          break
        ;;
        "清空")
          unset NGINX_CONFIG_ARR_STATIC
          break
        ;;
        "查看所有")
          local array=
          for key in ${!NGINX_CONFIG_ARR_STATIC[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_CONFIG_ARR_STATIC[${key}]}\"},"
          done
          F_log_info "[${array%,*}]"
          break
        ;;
        "返回")
          keepLoop=1
          break
        ;;
        *)
          F_log_err "未知选项"
          break
        ;;
      esac
    done
    if [[ $keepLoop -eq 1 ]]; then
        break
    fi
  done
}

F_build_cmd_web(){
  local keepLoop=0
  local options=("新增" "修改" "删除" "查询" "清空" "查看所有" "返回")
  local PS3="[指令构建-web工程] 请选择指令 => "
  while true 
  do
    echo
    F_log_info $'--> 选择执行的指令'
    select option in ${options[@]}; do
      case $option in
        "新增")
          read -e -p "Key(Uri)[如:/backend]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_WEB[${key}]}
          if [[ x"${value}" = x"" ]]; then
            read -e -p "Value(/web/{Your_Relative_Path_No_End_/})[如:root/demo]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_WEB["${key}"]="/web/${value}"
            fi
          else
            F_log_err " ${key} 已存在"
          fi
          break
        ;;
        "修改") 
          read -e -p "Key(Uri)[如:/backend]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_WEB[${key}]}
          if [[ x"${value}" != x"" ]]; then
            read -e -p "Value(/web/{Your_Relative_Path_No_End_/})[如:root/demo]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_WEB["${key}"]="/web/${value}"
            fi
          else
            F_log_err " ${key} 不存在"
          fi
          break
        ;;
        "删除") 
          read -p "删除Key值(Uri)=> " -e key
          if [[ $? -eq 0 && x"${key}" != "" ]]; then
            unset NGINX_CONFIG_ARR_WEB["${key}"]
          fi
          break
        ;;
        "查询")
          read -p "查询Key值(Uri)=> " -e key
          F_log_info "${key} : ${NGINX_CONFIG_ARR_WEB[${key}]}"
          break
        ;;
        "清空")
          unset NGINX_CONFIG_ARR_WEB
          break
        ;;
        "查看所有")
          local array=
          for key in ${!NGINX_CONFIG_ARR_WEB[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_CONFIG_ARR_WEB[${key}]}\"},"
          done
          F_log_info "[${array%,*}]"
          break
        ;;
        "返回")
          keepLoop=1
          break
        ;;
        *)
          F_log_err "未知选项"
          break
        ;;
      esac
    done
    if [[ $keepLoop -eq 1 ]]; then
        break
    fi
  done
}

F_build_cmd_proxy(){
  local keepLoop=0
  local options=("新增" "修改" "删除" "查询" "清空" "查看所有" "返回")
  local PS3="[指令构建-API代理] 请选择指令 => "
  while true 
  do 
    echo
    F_log_info $'--> 选择执行的指令'
    select option in ${options[@]}; do
      case $option in
        "新增")
          read -e -p "Key(Uri)[如:/prod-api/]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_PROXY_API[${key}]}
          if [[ x"${value}" = x"" ]]; then
            read -e -p "Value(URL)[如:http://172.20.1.13:2102/]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_PROXY_API["${key}"]="${value}"
            fi
          else
            F_log_err " ${key} 已存在"
          fi
          break
        ;;
        "修改") 
          read -e -p "Key(Uri)[如:/prod-api/]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          local value=${NGINX_CONFIG_ARR_PROXY_API[${key}]}
          if [[ x"${value}" != x"" ]]; then
            read -e -p "Value(URL)[如:http://172.20.1.13:2102/]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_CONFIG_ARR_PROXY_API["${key}"]="${value}"
            fi
          else
            F_log_err " ${key} 不存在"
          fi
          break
        ;;
        "删除") 
          read -p "删除Key值(Uri)=> " -e key
          if [[ $? -eq 0 && x"${key}" != "" ]]; then
            unset NGINX_CONFIG_ARR_PROXY_API["${key}"]
          fi
          break
        ;;
        "查询")
          read -p "查询Key值(Uri)=> " -e key
          F_log_info "${key} : ${NGINX_CONFIG_ARR_PROXY_API[${key}]}"
          break
        ;;
        "清空")
          unset NGINX_CONFIG_ARR_PROXY_API
          break
        ;;
        "查看所有")
          local array=
          for key in ${!NGINX_CONFIG_ARR_PROXY_API[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_CONFIG_ARR_PROXY_API[${key}]}\"},"
          done
          F_log_info "[${array%,*}]"
          break
        ;;
        "返回")
          keepLoop=1
          break
        ;;
        *)
          F_log_err "未知选项"
          break
      esac
    done
    if [[ $keepLoop -eq 1 ]]; then
        break
    fi
  done
}

F_build_config_by_cmd_to_file(){
  # 构建配置文件
  echo "server {" > "${NGINX_TMP_CONFIG_FILE}"
  {
    echo "  listen ${NGINX_CONFIG_VAR_PORT:-80};"
    echo "  server_name localhost;"
    echo "  ${NGINX_CONFIG_VAR_BODY_SIZE}"
  } >> "${NGINX_TMP_CONFIG_FILE}"

  # 构建多个静态资源
  if [[ "${#NGINX_CONFIG_ARR_STATIC[@]}" -ne 0 ]]; then
    for key in ${!NGINX_CONFIG_ARR_STATIC[@]}
    do
      cat >> ${NGINX_TMP_CONFIG_FILE} <<EOF

  location ${key} {
    alias ${NGINX_CONFIG_ARR_STATIC[${key}]};
    autoindex on;
  }
EOF
    done
  fi

  # 构建多个Web工程
  if [[ "${#NGINX_CONFIG_ARR_WEB[@]}" -ne 0 ]]; then
    for key in ${!NGINX_CONFIG_ARR_WEB[@]}
    do
      cat >> ${NGINX_TMP_CONFIG_FILE} <<EOF

  location ${key} {
    root   ${NGINX_CONFIG_ARR_WEB[${key}]};
    try_files \$uri \$uri/ /index.html;
    index  index.html index.htm;
  }
EOF
    done
  fi

  # 构建多个API代理
  if [[ "${#NGINX_CONFIG_ARR_PROXY_API[@]}" -ne 0 ]]; then
    for key in ${!NGINX_CONFIG_ARR_PROXY_API[@]}
    do
      cat >> ${NGINX_TMP_CONFIG_FILE} <<EOF

  location ${key} {
    proxy_pass ${NGINX_CONFIG_ARR_PROXY_API[${key}]};
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_read_timeout 10m;
    proxy_send_timeout 10m;
  }
EOF
    done
  fi

  echo "}" >> "${NGINX_TMP_CONFIG_FILE}"
}

F_build_config_by_cmd(){

  local PS3="[指令构建] 请选择指令 => "
  local options=("配置端口" "配置上传文件大小" "配置静态资源" "配置web工程" "配置API代理" "查看Nginx配置" "返回")

  local is_Integer_re='^[0-9]+$'
  while true 
  do
    local is_exit_loop=0
    echo
    F_log_info $'--> 选择执行的指令'
    select option in ${options[@]}; do
      case $option in
        "查看Nginx配置")
          F_build_config_by_cmd_to_file
          cat ${NGINX_TMP_CONFIG_FILE}
          break
        ;;
        "配置端口")
          F_build_cmd_set_port
          break;
        ;;
        "配置上传文件大小")
          F_build_cmd_set_body_size
          break
        ;;
        "配置静态资源") 
          F_build_cmd_static
          break
        ;;
        "配置web工程")
          F_build_cmd_web
          break
        ;;
        "配置API代理")
          F_build_cmd_proxy
          break
        ;;
        "返回")
          is_exit_loop=1
          break
        ;;
        *)
          F_log_err "未知的选项"
          break
        ;;
      esac
    done

    if [[ $is_exit_loop -eq 1 ]]; then
      break;
    fi
  done
  
  F_build_config_by_cmd_to_file
}

F_create_nginx_config(){
  
  local config_text=$(echo '
server {
  listen       80;
  server_name  localhost;
  location / {
      root   /web;
      try_files $uri $uri/ /index.html;
      index  index.html index.htm;
  }
  location /download {
      alias /download/;
      autoindex on;
  }
}
  ')

  local options=("默认配置" "指令生成" "粘贴生成" "跳过")
  local PS3="选择序号，回车确认:"
  F_log_note "[USER]---> 进行Nginx配置，请选择:"
  echo "
【默认配置】
  在 /etc/nginx/conf.d/ 覆盖default.conf, 默认配置Web,静态资源映射,监听80端口

【指令生成】
  自定义生成 /etc/nginx/conf.d/default.conf
  其内容可配置指令来生成

【粘贴生成】
  自定义生成 /etc/nginx/conf.d/default.conf
  其内容直接粘贴文本生成

【跳过】
  直接使用默认的配置文件或者在后续挂载时指定宿主机上的配置文件
  "

  select option in ${options[@]}; do
    case ${option} in
      "默认配置")
        echo "${config_text}" > ${NGINX_TMP_CONFIG_FILE}
        break
        ;;
      "指令生成")
        F_build_config_by_cmd
        break
        ;;
      "粘贴生成")
        echo "粘贴配置，按 ctrl-d 确定:"
        config_text=$(cat)
        echo "${config_text}" > ${NGINX_TMP_CONFIG_FILE}
        break
        ;;
      "跳过") 
        break 
      ;;
    esac
  done

  if test -e "${NGINX_TMP_CONFIG_FILE}" ; then
    F_log_info " --> 当前生效的配置文件内容如下:"
    cat ${NGINX_TMP_CONFIG_FILE}
  fi
}

F_config_volume_by_custom(){
  local keepLoop=0
  local options=("新增" "修改" "删除" "查询" "清空" "查看所有" "返回")
  local PS3="[自定义volume] 请选择指令 => "
  while true 
  do
    echo
    F_log_info $'--> 选择执行的指令'
    select option in ${options[@]}; do
      local key=
      local value=
      case $option in
        "新增")
          read -e -p "Key(宿主机绝对路径)[如:/home/nginx/log]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          value=${NGINX_VOLUME_ARR_MOUNT[${key}]}
          if [[ x"${value}" = x"" ]]; then
            read -e -p "Value(容器绝对路径)[如:/web/project]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_VOLUME_ARR_MOUNT["${key}"]="${value}"
            fi
          else
            F_log_err " ${key} 已存在"
          fi
          break
        ;;
        "修改") 
          read -e -p "Key(宿主机绝对路径)[如:/home/nginx/log]=> " key
          if [[ $? -ne 0 || x"$key" = x"" ]]; then
            break
          fi

          value=${NGINX_VOLUME_ARR_MOUNT[${key}]}
          if [[ x"${value}" != x"" ]]; then
            read -e -p "Value(容器绝对路径)[如:/web/project]=> " value
            if [[ $? -eq 0 && x"$value" != x"" ]]; then
              NGINX_VOLUME_ARR_MOUNT["${key}"]="${value}"
            fi
          else
            F_log_err " ${key} 不存在"
          fi
          break
        ;;
        "删除") 
          read -p "删除Key值(宿主机绝对路径)=> " -e key
          if [[ $? -eq 0 && x"${key}" != "" ]]; then
            unset NGINX_VOLUME_ARR_MOUNT["${key}"]
          fi
          break
        ;;
        "查询")
          read -p "查询Key值(宿主机绝对路径)=> " -e key
          F_log_info "${key} : ${NGINX_VOLUME_ARR_MOUNT[${key}]}"
          break
        ;;
        "清空")
          unset NGINX_VOLUME_ARR_MOUNT
          break
        ;;
        "查看所有")
          local array=
          for key in ${!NGINX_VOLUME_ARR_MOUNT[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_VOLUME_ARR_MOUNT[${key}]}\"},"
          done
          F_log_info "[${array%,*}]"
          break
        ;;
        "返回")
          keepLoop=1
          break
        ;;
        *)
          F_log_err "未知选项"
          break
        ;;
      esac
    done
    if [[ $keepLoop -eq 1 ]]; then
        break
    fi
  done
}

F_config_volume(){
  local options=("Nginx主配置文件" "Nginx日志目录" "Nginx配置目录" "自定义挂载目录" "查看配置" "确认" )
  local PS3="选择配置项=> "
  F_log_info "默认不挂载主配置文件，日志目录，配置目录"
  F_log_info "默认挂载容器内的 /web /download 到宿主机的 ${NGINX_ROOT_DIR}/{容器名}/{web,download}"

  declare -A NGINX_VOLUME_ARR_MOUNT=(["${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/web"]="/web" ["${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/download"]="/download")

  local mount_main_config=0
  local mount_log_dir=0
  local mount_config_dir=0
  local keepLoop=0

  while true 
  do
    F_log_info "----Volume配置项----"
    select option in ${options[@]}; do
      case $option in
        "查看配置")
          echo "Nginx主配置文件(0:不挂载,非零值:挂载):${mount_main_config}"
          echo "Nginx日志目录(0:不挂载,非零值:挂载):${mount_log_dir}"
          echo "Nginx配置目录(0:不挂载,非零值:挂载):${mount_config_dir}"
          local array=
          for key in ${!NGINX_VOLUME_ARR_MOUNT[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_VOLUME_ARR_MOUNT[${key}]}\"},"
          done
          echo "自定义挂载目录映射:[${array%,*}]"
          break
        ;;
        "Nginx主配置文件")
          read -p "0=不挂载，非零值=挂载，默认0，请输入=>" mount_main_config
          echo
          break
        ;;
        "Nginx日志目录")
          read -p "0=不挂载，非零值=挂载，默认0，请输入=>" mount_log_dir
          echo
          break
        ;;
        "Nginx配置目录")
          read -p "0=不挂载，非零值=挂载，默认0，请输入=>" mount_config_dir
          echo
          break
        ;;
        "自定义挂载目录")
          F_config_volume_by_custom
          echo
          break
        ;;
        "确认")
          keepLoop=1
          echo
          break
        ;;
        *) 
          F_log_err "未知选项"
          break
        ;;
      esac
    done

    if [[ keepLoop -eq 1 ]]; then
      break
    fi
  done

  NGINX_VOLUME_COMMAND=" -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime "
  docker run --name ${NGINX_TMP_CONTAINER_NAME} -d nginx:${NGINX_VERSION} > /dev/null
  if [[ $? -ne 0 ]]; then
    docker stop ${NGINX_TMP_CONTAINER_NAME} > /dev/null && docker rm ${NGINX_TMP_CONTAINER_NAME} > /dev/null
    F_exit_unexpected 1 "启动临时容器 ${NGINX_TMP_CONTAINER_NAME} 失败"
  fi
  
  if [[ ${mount_main_config} -ne 0 ]]; then
    mkdir -p ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}
    local _local_main_config_file_=${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/nginx.conf
    test -e ${_local_main_config_file_} || docker cp ${NGINX_TMP_CONTAINER_NAME}:/etc/nginx/nginx.conf ${_local_main_config_file_}
    NGINX_VOLUME_COMMAND=" ${NGINX_VOLUME_COMMAND}
     -v ${_local_main_config_file_}:/etc/nginx/nginx.conf "
  fi
  
  if [[ ${mount_log_dir} -ne 0 ]]; then
    mkdir -p ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/log
    NGINX_VOLUME_COMMAND=" ${NGINX_VOLUME_COMMAND}
     -v ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/log:/var/log/nginx "
  fi

  if [[ ${mount_config_dir} -ne 0 ]]; then
    mkdir -p ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/conf.d
    if test -e "${NGINX_TMP_CONFIG_FILE}" ; then
      F_log_info " --> 检测到您已经自定义了Nginx配置，剪切到${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/conf.d"
      mv ${NGINX_TMP_CONFIG_FILE} ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/conf.d
    fi

    NGINX_VOLUME_COMMAND=" ${NGINX_VOLUME_COMMAND}
     -v ${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/conf.d:/etc/nginx/conf.d "
  fi

  local mkdirs_entrypoint_file="${NGINX_ROOT_DIR}/${DOCKER_CONTAINER_NAME}/40_mkdirs_entrypoint.sh"
  echo '#!/usr/bin/env bash' > ${mkdirs_entrypoint_file}

  if [[ ${#NGINX_VOLUME_ARR_MOUNT[@]} -ne 0 ]]; then
    for key in ${!NGINX_VOLUME_ARR_MOUNT[@]}
    do
      local _container_path_="${NGINX_VOLUME_ARR_MOUNT[${key}]}"
      
      NGINX_VOLUME_COMMAND=" ${NGINX_VOLUME_COMMAND} 
      -v ${key}:${_container_path_} "
    done
  fi

  if [[ ${#NGINX_CONFIG_ARR_STATIC[@]} -ne 0 ]]; then
    for static_dir in ${NGINX_CONFIG_ARR_STATIC[@]}
    do
          cat >> ${mkdirs_entrypoint_file} <<EOF
mkdir -p "${static_dir}"
EOF
    done
  fi

  if [[ ${#NGINX_CONFIG_ARR_WEB[@]} -ne 0 ]]; then
    for web_dir in ${NGINX_CONFIG_ARR_WEB[@]}
    do
      cat >> ${mkdirs_entrypoint_file} <<EOF
mkdir -p "${web_dir}"
EOF
    done
  fi

  chmod 775 ${mkdirs_entrypoint_file}
  NGINX_VOLUME_COMMAND=" ${NGINX_VOLUME_COMMAND} 
  -v ${mkdirs_entrypoint_file}:/docker-entrypoint.d/40_mkdirs_entrypoint.sh "

  docker stop ${NGINX_TMP_CONTAINER_NAME} > /dev/null && docker rm ${NGINX_TMP_CONTAINER_NAME} > /dev/null
}

F_config_port_map(){
  local keepLoop=0
  local options=("新增" "修改" "删除" "查询" "清空" "查看所有" "返回")
  local PS3="[自定义端口映射] 请选择指令 => "

  while true 
  do
    echo
    F_log_info $'--> 选择执行的指令'
    select option in ${options[@]}; do
      local key=
      local value=
      case $option in
        "新增")
          read -e -p "Key(容器暴露的端口)=> " key
          if [[ $? -ne 0 || x"$key" = x"" || ! $key =~ $is_Integer_re ]]; then
            F_log_err "非法输入"
            break
          fi

          value=${NGINX_NET_PORT_MAP[${key}]}
          if [[ x"${value}" = x"" ]]; then
            read -e -p "Value(宿主机暴露的端口，缺省为Key值)=> " value
            value=${value:-$key}
            if [[ $? -eq 0 && x"$value" != x"" && $value =~ $is_Integer_re ]]; then
              NGINX_NET_PORT_MAP["${key}"]="${value}"
            else
              F_log_err "非法输入"
              break
            fi
          else
            F_log_err " ${key} 已存在"
          fi
          break
        ;;
        "修改") 
          read -e -p "Key(容器暴露的端口)=> " key
          if [[ $? -ne 0 || x"$key" = x"" || ! $key =~ $is_Integer_re ]]; then
            F_log_err "非法输入"
            break
          fi

          value=${NGINX_NET_PORT_MAP[${key}]}
          if [[ x"${value}" != x"" ]]; then
            read -e -p "Value(宿主机暴露的端口，缺省为Key值)=> " value
            if [[ $? -eq 0 && x"$value" != x"" && $value =~ $is_Integer_re ]]; then
              NGINX_NET_PORT_MAP["${key}"]="${value}"
            fi
          else
            F_log_err " ${key} 不存在"
          fi
          break
        ;;
        "删除") 
          read -p "删除Key值(容器暴露的端口)=> " -e key
          if [[ $? -eq 0 && x"${key}" != "" ]]; then
            unset NGINX_NET_PORT_MAP["${key}"]
          fi
          break
        ;;
        "查询")
          read -p "查询Key值(容器暴露的端口)=> " -e key
          F_log_info "${key} : ${NGINX_NET_PORT_MAP[${key}]}"
          break
        ;;
        "清空")
          unset NGINX_NET_PORT_MAP
          break
        ;;
        "查看所有")
          local array=
          for key in ${!NGINX_NET_PORT_MAP[@]}
          do
            array="${array}{\"${key}\" : \"${NGINX_NET_PORT_MAP[${key}]}\"},"
          done
          F_log_info "[${array%,*}]"
          break
        ;;
        "返回")
          keepLoop=1
          break
        ;;
        *)
          F_log_err "未知选项"
          break
      esac
    done
    if [[ $keepLoop -eq 1 ]]; then
        break
    fi
  done

  for key in ${!NGINX_NET_PORT_MAP[@]}
  do
    NGINX_NET_COMMAND="${NGINX_NET_COMMAND} -p ${key}:${NGINX_NET_PORT_MAP[${key}]} "
  done
}

F_config_net(){
  declare -A NGINX_NET_PORT_MAP=(["${NGINX_CONFIG_VAR_PORT:-80}"]="${NGINX_CONFIG_VAR_PORT:-80}")
  local options=("Host:桥接模式" "bridge:默认模式")
  local keepLoop=0
  while true
  do
    F_log_info "----选择你的网络模式----"
    select option in ${options[@]}; do
      case $option in
        "Host:桥接模式") 
          NGINX_NET_COMMAND=" --network=host "
          keepLoop=1
          break
        ;;
        "bridge:默认模式") 
          F_config_port_map
          keepLoop=1
          break
        ;;
        *) 
          F_log_err "未知选项"
          break
        ;;
      esac
    done

    if [[ $keepLoop -eq 1 ]]; then
      break
    fi
  done

  for key in ${!NGINX_NET_PORT_MAP[@]}
  do
    F_permit_port "${NGINX_NET_PORT_MAP[${key}]}/tcp"
  done
}

#---------------------------------------------------------------------------------------------------
#main

F_log_info "[1] 检查Docker环境"
systemctl status docker > /dev/null 2>&1
F_exit_unexpected $? "---> docker 环境异常" "---> Pass"

F_log_info "[2] 配置参数"
F_set_config

F_log_info "[3] 配置Nginx"

F_create_nginx_config

F_log_info "[4] 配置 Volume 相关参数"
F_config_volume

F_log_info "[5] 配置网络模式"
F_config_net

F_log_info "[6] 启动容器"
F_docker_run_command
F_exit_unexpected $? "启动容器失败"

if test -e "${NGINX_TMP_CONFIG_FILE}"
then
  docker cp ${NGINX_TMP_CONFIG_FILE} ${DOCKER_CONTAINER_NAME}:/etc/nginx/conf.d && \
  rm -I ${NGINX_TMP_CONFIG_FILE} && \
  docker stop ${DOCKER_CONTAINER_NAME} > /dev/null && \
  docker start ${DOCKER_CONTAINER_NAME} > /dev/null

  F_exit_unexpected $? "处理缓存的Nginx配置文件失败"
fi

F_log_info "启动容器成功，脚本退出"