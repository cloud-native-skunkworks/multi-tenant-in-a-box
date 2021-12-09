# multi-tenant-in-a-box

This project is designed to explore the nested virtualisation feature enabled within GCE Haswell based process families.


## GCE Creation

```
❯  gcloud compute instances create sre-testbed \
  --enable-nested-virtualization \
  --zone=europe-west2-a \
  --min-cpu-platform="Intel Haswell"  --custom-cpu=4 --custom-memory=12
Created [https://www.googleapis.com/compute/v1/projects/consummate-yew-302509/zones/europe-west2-a/instances/sre-testbed].


NAME         ZONE            MACHINE_TYPE    PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP  STATUS
sre-testbed  europe-west2-a  custom-4-12288               10.154.0.32  34.89.33.41  RUNNING
```

## Customisation

Once logged in via the ssh console...

0. Install KVM

```
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo adduser `id -un` libvirtd
sudo modprobe -a kvm
 ```

1. Iptables update
```
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

2. Components 
  
```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

3. Components II
```
# As root
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl wget

```

_And virtctl_

```
export VERSION=v0.41.0
wget https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64
chmod +x virtctl-v0.41.0-linux-amd64
sudo mv virtctl-v0.41.0-linux-amd64 /usr/local/bin/virtctl
```

4. Install docker

```
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
echo 'deb [arch=amd64] https://download.docker.com/linux/debian stretch stable' > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y --no-install-recommends docker-ce
```

5. Start cluster

```
kubeadm init --pod-network-cidr=10.244.0.0/16
```

And update user kubeconfig...

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

6. Kubectl setup

```
kubectl taint nodes sre-testbed node-role.kubernetes.io/master:NoSchedule-
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

7. Install Kubevirt

```
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | sort -r | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
echo $VERSION
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml

kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml
kubectl create configmap kubevirt-config -n kubevirt --from-literal debug-useEmulation=true
```

### Enable hotplugvolumes

```
cat << END > enable-feature-gate.yaml
---
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  configuration:
    developerConfiguration: 
      featureGates:
        - HotplugVolumes
END

kubectl apply -f enable-feature-gate.yaml
```

### Deploy a VM (Copy yaml over ssh)

```
kubectl apply -f vm.yaml
virtctl start testvm
```

## Deploy PVCS (Copy yaml over ssh)

```
kubectl apply -f pvc.yaml
```
### Attach PVCs (Copy yaml over ssh)

```
virtctl addvolume testvm --volume-name=claim-0
virtctl addvolume testvm --volume-name=claim-1
virtctl addvolume testvm --volume-name=claim-2
```

_We should see the hotplug volume attaching with our three PVCs

```
alex@sre-testbed:~$ kubectl get pods --all-namespaces -w
NAMESPACE            NAME                                      READY   STATUS    RESTARTS   AGE
default              hp-volume-rx8g4                           1/1     Running   0          9s
default              virt-launcher-testvm-r72dv                2/2     Running   0          54s
```

And looking inside the vm `virtctl console testvm`
