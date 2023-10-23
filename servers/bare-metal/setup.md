### **Welcome to the bare metal-setup wiki**

Kubernetes cluster on bare metal is a good choice. challenges of bare-metal are,  we will not get cloud-native features like load balancer and cloud-native storage, etc.. in order to achieve those we need to depend on other solutions like mettallb service for the load balancer. Nevertheless, an on-premise cluster is a good choice, we can achieve this by following a few steps mentioned below. Good luck.

**We are going to configure Kubernetes on Ubuntu 22.04.2**

** apply the below steps up to step 10 on both master and worker nodes**

1. sudo apt-get install docker.io

2. sudo systemctl enable docker

3. sudo systemctl status docker

4. sudo apt-get install curl

5. curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add

6. sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

7. sudo apt-get install kubeadm kubelet kubectl

8. sudo apt-mark hold kubeadm kubelet kubectl

9. sudo kubeadm version

10. sudo swapoff -a

**Below step apply only on Master node**

11. sudo hostnamectl set-hostname kmaster

**Below step apply onlyon Worker node**

12. sudo hostnamectl set-hostname kworker

** Below step apply only on Master node**

13. sudo kubeadm init --pod-network-cidr=10.244.0.0/16

14. mkdir -p $HOME/.kube

15. sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

16. sudo chown $(id -u):$(id -g) $HOME/.kube/config

17. kubectl get nodes

18. wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

19. kubectl apply -f kube-flannel.yml

20. kubectl get nodes

21. kubeadm token create --print-join-command

22. Join to cluster from Worker nodes

23. kubectl get nodes

**Metallb Loadbalancer deployment**

24. kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml

25. kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml

26. kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

27. kubectl -n metallb-system get all

**Create a YAML file for configuring metallb IP pool**

28. vi /tmp/metallb.yaml

**copy the contents of metallb.yaml that is  attached below , save and exit **

[metallb.yaml](https://github.com/kubernetesway/kubernetes/blob/main/metallb.yaml)

29. kubectl create -f /tmp/metallb.yaml

30. kubectl -n metallb-system get all

**Deploying a sample Nginx web application**

30. kubectl create deploy nginx --image nginx

31. kubectl get deployments

32. kubectl expose deploy nginx --port 80 --type LoadBalancer

33. kubectl get svc


