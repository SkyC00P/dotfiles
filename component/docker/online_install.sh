#!/usr/bin/env bash
################################################################################
## Name: 全新环境使用yum安装最新的docker
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS系统的纯净环境
## 
################################################################################

sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io
systemctl start docker
docker run hello-world

# 修改docker镜像地址
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "data-root": "/home/docker-data",
  "storage-driver": "overlay2",
  "registry-mirrors":
  [
      "https://docker.mirrors.ustc.edu.cn",
      "http://hub-mirror.c.163.com",
      "https://7f5rcv6e.mirror.aliyuncs.com"
  ]
}
EOF

# 开启开机自启动
systemctl enable docker

# 开启远程控制
key__='ExecStart';
value__='/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock';
path__='/lib/systemd/system/docker.service'
grep "tcp://0.0.0.0:2375" ${path__} || sed -i "s|${key__}=.*$|${key__}=${value__:-""}|g" ${path__};

systemctl daemon-reload
systemctl restart docker

# 确认启动成功
sudo docker run hello-world;

curl http://localhost:2375/version