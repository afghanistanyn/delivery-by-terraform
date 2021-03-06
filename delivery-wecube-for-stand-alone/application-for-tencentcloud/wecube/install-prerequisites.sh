#!/bin/bash

set -e

echo -e "\nChecking prerequisites...\n"
PREREQUISITES_SATISFIED=''
if [ "$PREREQUISITES_SATISFIED" != 'false' ] && ! $(docker version >/dev/null 2>&1); then
  echo 'Docker Engine is not properly installed!'
  PREREQUISITES_SATISFIED='false'
fi
if [ "$PREREQUISITES_SATISFIED" != 'false' ] && ! $(docker-compose version >/dev/null 2>&1); then
  echo 'Docker Compose is not properly installed!'
  PREREQUISITES_SATISFIED='false'
fi
if [ "$PREREQUISITES_SATISFIED" != 'false' ] && ! $(curl -sSLf http://127.0.0.1:2375/version >/dev/null 2>&1); then
  echo 'Docker Engine is not listening on port 2375!'
  PREREQUISITES_SATISFIED='false'
fi

if [ "$PREREQUISITES_SATISFIED" != 'false' ]; then
  echo "Congratulations, all prerequisites are satisfied."
  exit 0
fi


echo -e "\nInstalling prerequisites...\n"

# 移除已安装的旧版本Docker
yum remove docker \
           docker-client \
           docker-client-latest \
           docker-common \
           docker-latest \
           docker-latest-logrotate \
           docker-logrotate \
           docker-engine

# 安装工具组件
yum install -y yum-utils device-mapper-persistent-data lvm2 unzip

# 安装Docker
#yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

# 安装Docker Compose
curl -L --fail https://github.com/docker/compose/releases/download/1.25.4/run.sh -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 配置Docker Engine以监听远程API请求
# 我们在这里启用了腾讯云的Docker Hub镜像为中国大陆境内的访问进行加速，请根据您自己的实际情况进行调整
mkdir -p /etc/systemd/system/docker.service.d
cat <<EOF >/etc/systemd/system/docker.service.d/docker-wecube-override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --registry-mirror=https://mirror.ccs.tencentyun.com
EOF

# 启动Docker服务
systemctl enable docker.service
systemctl start docker.service

# 启用IP转发并配置桥接来解决Docker容器对外部网络的通信问题
cat <<EOF >/etc/sysctl.d/zzz.net-forward-and-bridge-for-docker.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/zzz.net-forward-and-bridge-for-docker.conf

echo -e "\nVerifying prerequisites installation...\n"
docker version || (echo 'Docker Engine is not properly installed!' && exit 1)
docker-compose version || (echo 'Docker Compose is not properly installed!' && exit 1)
curl -sSLf http://127.0.0.1:2375/version || (echo 'Docker Engine is not listening on TCP port 2375!' && exit 1)

echo "Prerequisites installation completed."
