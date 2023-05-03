#!/usr/bin/env bash
################################################################################
## Name: docker 单实例部署GitLab
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
################################################################################

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

# configuration, logs, data files 存储的位置
export GITLAB_HOME=/srv/gitlab
mkdir -p ${GITLAB_HOME}
chmod 666 ${GITLAB_HOME}

sudo docker run --detach \
  --hostname gitlab.example.com \
  --publish 11443:443 --publish 1180:80 --publish 1122:22 \
  --name gitlab \
  --restart always \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  --shm-size 256m \
  gitlab/gitlab-ce:latest

F_permit_port 11443/tcp
F_permit_port 1180/tcp
F_permit_port 1122/tcp