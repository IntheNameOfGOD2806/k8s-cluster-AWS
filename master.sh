#!/bin/bash
set -e

# Set hostname
echo "-------------Setting hostname-------------"
hostnamectl set-hostname $1
#set lb ip
LB_IP=$2
LB_PUBLIC_IP=$3

# Disable swap
echo "-------------Disabling swap-------------"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install Containerd
echo "-------------Installing Containerd-------------"
wget https://github.com/containerd/containerd/releases/download/v1.7.4/containerd-1.7.4-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.4-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mkdir -p /usr/local/lib/systemd/system
mv containerd.service /usr/local/lib/systemd/system/containerd.service

# --- FIX: Generate default config and enable SystemdCgroup ---
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# -----------------------------------------------------------

systemctl daemon-reload
systemctl enable --now containerd

# Install Runc
echo "-------------Installing Runc-------------"
wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# Install CNI
echo "-------------Installing CNI-------------"
wget https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.2.0.tgz

# Install CRICTL
echo "-------------Installing CRICTL-------------"
VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Forwarding IPv4 and letting iptables see bridged traffic
echo "-------------Setting IPTables-------------"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
modprobe br_netfilter
sysctl -p /etc/sysctl.conf

# Install kubectl, kubelet and kubeadm
echo "-------------Installing Kubectl, Kubelet and Kubeadm-------------"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "-------------Pulling Kubeadm Images -------------"
kubeadm config images pull

echo "-------------Running kubeadm init-------------"
# Initialize the cluster with WeaveNet as the pod network

kubeadm init --pod-network-cidr=10.244.0.0/16 \
    --apiserver-cert-extra-sans="$LB_PUBLIC_IP" \
    --control-plane-endpoint="$LB_IP:6443"

echo "-------------Copying Kubeconfig-------------"
# 1. Setup for ROOT (so the script itself can run kubectl later)
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# 2. Setup for UBUNTU USER (so Ansible/SSH user can run kubectl)
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "Waiting for API Server to stabilize..."
sleep 20

echo "-------------Deploying Flannel Pod Networking-------------"
# Uses the exported KUBECONFIG from above
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
# Deploy Ingress Nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "nodePort": 32222}, {"name": "https", "port": 443, "nodePort": 32223}]}}'

echo "-------------Creating join command file-------------"
# Save the command to the ubuntu home directory and change ownership
kubeadm token create --print-join-command | tee /home/ubuntu/join-command.sh
chown ubuntu:ubuntu /home/ubuntu/join-command.sh
chmod +x /home/ubuntu/join-command.sh

echo "Master node setup complete!"

# Install NFS server
sudo apt install nfs-common -y

# Upload certs for other master nodes
echo "-------------Generating Join Command for Master Nodes-------------"

CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs | tail -n 1)

JOIN_CMD=$(sudo kubeadm token create --print-join-command)


FULL_MASTER_JOIN_CMD="$JOIN_CMD --control-plane --certificate-key $CERT_KEY"


echo "$FULL_MASTER_JOIN_CMD" | tee /home/ubuntu/join-command-master.sh

# Phân quyền cho user ubuntu
chown ubuntu:ubuntu /home/ubuntu/join-command-master.sh
chmod +x /home/ubuntu/join-command-master.sh

