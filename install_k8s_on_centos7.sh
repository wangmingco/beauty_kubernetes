#/bin/bash

function clone_repo() {
	command -v git >/dev/null 2>&1 || { yum install -y git; }
	
	git clone https://github.com/wangmingco/beauty_kubernetes.git
}

function config_firewall() {
	echo "1.----------------------开始设置防火墙-----------------------"
	systemctl disable firewalld
	systemctl stop firewalld

	setenforce 0

	sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
	
	cat /etc/selinux/config

	echo "1.----------------------防火墙设置完成-----------------------"
}

function config_swap() {
	echo "2.----------------------开始设置交换区-----------------------"
	modprobe br_netfilter

	cp /etc/sysctl.conf  /etc/sysctl.conf.bak

	cp ./sysctl.conf  /etc/sysctl.conf

	cat /etc/sysctl.conf

	sysctl -p

	swapoff -a
	
	echo "2.----------------------交换区设置完成-----------------------"
}

function config_yum_repo() {
	echo "3.----------------------开始设置yum源-----------------------"

	yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

	echo "3.----------------------yum源设置完成-----------------------"
}

function create_docker_daemon() {
	echo "4.----------------------创建docker#daemon.json-----------------------"

	mkdir -p /etc/docker
	
	cd $HOME/beauty_kubernetes
	
	/bin/cp -rf ./daemon.json  /etc/docker/daemon.json
	
	ls -al -h /etc/docker/daemon.json

	echo "4.----------------------docker#daemon.json创建完成-----------------------"
}

function install_docker() {
	echo "5.----------------------开始安装docker-----------------------"

	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum install -y docker-ce
	create_docker_daemon
	systemctl daemon-reload
	systemctl enable docker
	systemctl start docker
	
	echo "5.----------------------docker安装完成-----------------------"
}

function create_kubernetes_repo() {
	/bin/cp -rf ./kubernetes.repo /etc/yum.repos.d/kubernetes.repo
	
	ls -al -h /etc/yum.repos.d/kubernetes.repo
}

function install_kubernetes() {

	echo "6.----------------------开始安装kubernetes-----------------------"
	
	echo "创建kubernetes.repo 文件"
	create_kubernetes_repo
	
	echo "安装kubelet， kubeadm， kubectl"
	yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
	
	echo "修改init.default.yaml 文件"
	kubeadm config print init-defaults > ./init.default.yaml
	sed -i "s@imageRepository: k8s.gcr.io@imageRepository: registry.aliyuncs.com/google_containers@g" ./init.default.yaml
	
	echo "测试镜像拉取"
	kubeadm config images pull --config=init.default.yaml
	
	echo "启动kubelet"
	systemctl enable kubelet
	systemctl start kubelet
	
	echo "安装kubernetes master"
	kubeadm init --config=init.default.yaml
	
	echo "6.----------------------kubernetes安装完成-----------------------"
}

function call_all() {
	clone_repo

	config_firewall
	config_swap
	config_yum_repo

	install_docker
	install_kubernetes
}

if [ $# > 0 ] 
then
	for arg in $*; do
	    $arg
	done
else
	call_all
fi
