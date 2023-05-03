#!/usr/bin/env bash
################################################################################
## Name: docker 单实例部署在线预览服务 kkfileview
## Author:  skycoop
## Version: 1.0
##
## 仅适用于CentOS7系统
################################################################################

docker run -it -d --restart=always --name=kitop-kkfileview -p 8012:8012 keking/kkfileview:4.1.0