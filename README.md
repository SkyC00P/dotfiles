
收集汇总各种常见组件的一键式脚本，包括安装，卸载，更新，省略重复繁琐的操作。

该项目发布在GitHub上，在已经联网的CentOS服务器上执行以下命令便可以在线安装docker.

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/SkyC00P/dotfiles/dev/component/docker/online_install.sh)"
```

本质上就是把Github上面的脚本下载下来执行。只要URL满足`https://raw.githubusercontent.com/${Github_User}/${Github_project}/${Github_branch}/${File_Path}`

Github_User = Github用户
Github_project = Github项目名
Github_branch = 对应的Git分支
File_Path = 脚本路径

## Centos docker 安装脚本

开发最新版本

## Centos RabbitMQ 单实例脚本

sh -c "$(curl -fsSL https://raw.githubusercontent.com/SkyC00P/dotfiles/dev/component/rabbitmq/online_install.sh)"