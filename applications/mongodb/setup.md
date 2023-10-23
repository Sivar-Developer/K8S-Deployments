<p align="center">
  <a href="https://www.tornet.co/" target="_blank">
    <img src="https://webimages.mongodb.com/_com_assets/cms/kuyjf3vea2hg34taa-horizontal_default_slate_blue.svg?auto=format%252Ccompress" width="200" alt="TorNET Co Logo">
  </a>
</p>
<p align="center">
	<a href="https://www.tornet.co"><img src="https://flat.badgen.net/badge/K8S/MongoDB/f2a?color=001E2B" /></a>
	<a href="https://laravel.com"><img src="https://flat.badgen.net/badge/icon/GIT?icon=git&label&color=001E2B" /></a>
</p>

## Setup MongoDB on Kubernetes

### Persistent Storage

1. StorageClass: run `kubectl apply -f sc.yaml`

`sc.yaml` Example:

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: demo-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
parameters:
  type: local
  path: /var/www/storage

```
Check if the setup was ready `kubectl get sc`

2. Persistent Volume: run `kubectl apply -f pv.yaml`

`pv.yaml` Example:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain # Set according to your requirements
  storageClassName: demo-storage # Name of your storage class
  hostPath:
    path: /var/www/storage # Path on your dedicated server

```
Check if the setup was ready `kubectl get pv`

3. Persistent Volume Claim: run `kubectl apply -f pvc.yaml`

`pvc.yaml` Example:
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc-sc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: demo-storage
  resources:
    requests:
      storage: 10Gi

```
Check if the setup was ready `kubectl get pvc`


### Deployment
1. Deployment: run `kubectl apply -f deployment.yaml`

`deployment.yaml` Example:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - image: mongo:4.4.6
          name: mongo
          args: ["--dbpath", "/data/db"]
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "admin"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "password"
          volumeMounts:
            - mountPath: /data/db
              name: mongo-volume
      volumes:
        - name: mongo-volume
          persistentVolumeClaim:
            claimName: mongo-pvc-sc

```
Check if the setup was ready <br>
`kubectl get deployments` <br>
`kubectl get pods`

2. Service NodePort Expose: run `kubectl apply -f service.yaml`

`service.yaml` Example:

```
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc
spec:
  ports:
    - port: 27017
      protocol: TCP
      targetPort: 27017
      nodePort: 32000
  selector:
    app: mongo
  type: NodePort

```
check if the network is ready `kubectl get svc`

3. Expose NodePort:

on local you may use port forwarding:
`kubectl port-forward svc/mongo-svc 32000:27017`

on dedicated server you can use iptable:
`sudo iptables -t nat -A PREROUTING -p tcp --dport 32000 -j DNAT --to 10.109.231.73:32000
`

ClusterIP Example: 10.109.231.73
NodePort Example: 32000
