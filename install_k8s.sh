#!/bin/bash

set -e

echo "🔧 [1/8] Mise à jour du système et désactivation du swap"
apt update && apt upgrade -y
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "🔧 [2/8] Activation des modules nécessaires pour Kubernetes"
modprobe overlay
modprobe br_netfilter

tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "🐳 [3/8] Installation de containerd (runtime de conteneurs)"
apt install -y containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Correctif pour le driver CGroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

echo "📦 [4/8] Ajout du dépôt Kubernetes et installation de kubeadm, kubelet, kubectl"
apt install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key |
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" |
  tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "🚀 [5/8] Initialisation du cluster avec kubeadm (CIDR compatible Calico)"
kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.32.0

echo "🛠 [6/8] Configuration de kubectl pour l'utilisateur courant"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "🌐 [7/8] Installation de Calico comme CNI"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "⚙️ [8/8] Autorisation du scheduling sur le nœud master (mononœud)"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "✅ Kubernetes est prêt sur cette VM (mononœud avec Calico)."
kubectl get nodes -o wide
