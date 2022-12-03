1. Create 2 Instances and a security Group - We have a cloudformation template
    a. Master Node
    b. Slave Node

## Install these commands on all the nodes 

2. Install Container Runtime Engine - we are installing CRI-O
    a. Run this command 

        sudo apt update

        cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOF

        sudo modprobe overlay
        sudo modprobe br_netfilter

        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOF

        sudo sysctl --system

        OS=xUbuntu_20.04
        CRIO_VERSION=1.23
        echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
        echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list


        curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
        curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -

        sudo apt update
        sudo apt install cri-o cri-o-runc -y 

        sudo systemctl enable crio.service
        sudo systemctl start crio.service  

        sudo apt install cri-tools


3. Install Kubectl kubeadm kubelet     

        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl

        sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl


## Run these below commands on the Master node

4. Run the kubeadm init 

5. mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config

   ######https://172.31.11.1:6443

6. export KUBECONFIG=/etc/kubernetes/admin.conf

7. kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

8. kubeadm token create --print-join-command > /tmp/

9. Example token file - you can get this but running this 

    kubeadm token create --print-join-command

    kubeadm join 172.31.11.1:6443 --token d6lv2w.yrh89dkbsie3pv8x \
	--discovery-token-ca-cert-hash sha256:5977e99fa9a9e82f15f5c302d58f66bb31959315d3895166f8fa54c5baa74f75


## Now we have to make the cluster public so that Github actions can connect to API server

### Run all these commands in the master node 

1. Go to home directory and run 
    kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml

   Reason: we are taking and editing the Config Map of the Kubeadm 

2. Now edit the kubeadm.yaml file and add the following lines

    ```
    apiServer:
    certSANs:
        - "<public IP of the Master Node"
    extraArgs:
    ```

    Now the Config should look like 

    ```
    apiServer:
    certSANs:
        - "43.204.144.219"
    extraArgs:
        authorization-mode: Node,RBAC
    timeoutForControlPlane: 4m0s
    apiVersion: kubeadm.k8s.io/v1beta3
    certificatesDir: /etc/kubernetes/pki
    clusterName: kubernetes
    controllerManager: {}
    dns: {}
    etcd:
    local:
        dataDir: /var/lib/etcd
    imageRepository: registry.k8s.io
    kind: ClusterConfiguration
    kubernetesVersion: v1.25.4
    networking:
    dnsDomain: cluster.local
    serviceSubnet: 10.96.0.0/12
    scheduler: {}
    ```

3. Since we added the Cert SANs in the previous step the existing certs will become invalid so regenerate using the below command 

    sudo mv /etc/kubernetes/pki/apiserver.{crt,key} ~

    sudo kubeadm init phase certs apiserver --config kubeadm.yaml

  you will get an output like below 

  ```
  [certs] Generating "apiserver" certificate and key
    [certs] apiserver serving cert is signed for DNS names [controlplane kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 172.31.14.0 43.204.144.219]
  ```

4. Now restart the API server container by using the below commands 

    crictl ps | grep kube-apiserver | grep -v pause

5. Get the container ID from the above step and run the below 

    crictl stop <containerID>

6. Now check if the container is restarted 

    crictl ps 

7. Now Update the kubeconfig file with the public IP and test it using the cmd -> kubectl get nodes

8. Now Get the kubeconfig data from the master node and put in the GitHub action's secrets the variable name -> KUBE_CONFIG





