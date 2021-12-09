#!/bin/bash

sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo adduser `id -un` libvirtd
sudo modprobe -a kvm
# ----------------------------------------------------
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
# ----------------------------------------------------
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
# ----------------------------------------------------
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
# ----------------------------------------------------

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl wget
# ----------------------------------------------------
export VERSION=v0.41.0
wget https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64
chmod +x virtctl-v0.41.0-linux-amd64
sudo mv virtctl-v0.41.0-linux-amd64 /usr/local/bin/virtctl
# ----------------------------------------------------
sudo mkdir /etc/docker
sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo 'deb [arch=amd64] https://download.docker.com/linux/debian stretch stable' | sudo tee -a /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y --no-install-recommends docker-ce
# ----------------------------------------------------
