#!/bin/bash

# Update and upgrade the system
apt update && apt -y upgrade && apt -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Check memory and swap space
free -h
swapon -s

# Open /etc/fstab (this step requires manual intervention)
 echo "Please manually edit /etc/fstab to adjust swap settings"
# nano /etc/fstab

# Reboot the system 
# reboot

# Load necessary kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Verify modules
lsmod | egrep "br_netfilter|overlay"

# Set sysctl params required by Kubernetes
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl settings
sysctl --system

# Disable UFW (firewall)
systemctl stop ufw && systemctl disable ufw

# CRI-O Setup
export OS=xUbuntu_22.04
export CRIO_VERSION=1.25

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list

# Add keys for repositories
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -

# Install CRI-O and related tools
apt update && apt -y install cri-o cri-o-runc cri-tools

# Enable and start CRI-O service
systemctl start crio && systemctl enable crio
systemctl status crio

# Kubernetes installation
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install kubelet, kubeadm, and kubectl
apt update && apt -y install kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Verify Kubernetes installation
kubectl get nodes
kubectl get po -A

# Install Flannel CNI for pod networking
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

# Check Flannel pods
kubectl get po -n kube-flannel
