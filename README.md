# badPods

A collection of yamls that will create pods with different elevated privileges. The goal is to help you quickly understand the impact of allowing specific security sensitive pod specifications, and some common combinations, by giving you the tools to demonstrate exploitation.

## Background
Occasionally, containers within pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications, but it is not always clear what the real-world security implications of allowing certain attributes is. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. Permission to create pods in at least one namespace. If you can exec into them that makes life easier.  
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all


## Summary

Allowed Specification | What's the worst that can happen? | How?
-- | -- | -- 
[everything-allowed](yaml/everything-allowed/README.md) | Multiple likely paths to full cluster compromise (all resources in all namespaces) <img width=800/>| Once you create the pod, you can exec into it and you will have root access on the node running your pod. One promising privesc path is available if you can schedule your pod to run on the master node (not possible in a cloud managed environment). Even if you can only schedule your pod on the worker node, you can access the node's kubelet creds, you can create mirror pods in any namespace, and you can access any secret mounted within any pod on the node you are on, and then it to gain access to other namespaces or to create new cluster role bindings. 
[hostPID + privileged](yaml/priv-and-hostpid/README.md) |  Same as above | Same as above 
[privileged=true](yaml/priv-only/README.md) | Same as above | While can eventually get an interactive shell on the node like in the cases above, you start with non-interactive command execution and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above.
[Unrestricted hostmount (/)](yaml/hostpath-only/README.md) | Same as above | While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform the same types of privesc paths outlined above. Hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.
[hostpid](yaml/hostpid-only/README.md) | Unlikely but possible path to cluster compromise <br> | You can run `ps -aux` on the host. Look for any process that includes passwords, tokens, or keys, and use them to privesc within the cluster, to services supported by the cluster, or to services that cluster hosted applications are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin.   You can also kill any process on the node (DOS).  
[hostnetwork](yaml/hostnetwork-only/README.md) | Potential path to cluster compromise | Sniff unencrypted traffic on any interface on the host and potentially find service account tokens or other sensitive information that is transmitted over unencrypted channels. <br> You can also reach services that only listen on the host's loopback interface or are otherwise blocked by nework polices. These services might turn into a fruitful privesc path. 
[hostipc](yaml/hostipc-only/README.md) | Not seen often - but potential limited compromise |  If any process on the host, or any processes within a pod is using the host's interprocess communication mechanisms (shared memory, semaphore arrays, message queues, etc.), you will be able to read/write to those same mechanisms. That said, with things like message queues, even if you can read something in the queue, reading it is a destructive action that will remove it from the queue, so beware. 


**Caveat:** There are many kubernetes specific security controls available to administrators that can reduce the impact of pods created with the following privileges. As is always the case with penetration testing, your milage may vary.


# Example Usage
 Each resource in the `yamls` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. Each subdirectory has it's own usage information which includes tailored post-exploitation ideas and steps.  

### Create a pod

```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostpid-only.yaml   
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-hostpid-only.yaml  
```

### Exec into pod 
```bash 
kubectl exec -it pod-hostpid-only  -- bash
```
### Post exploitation
```bash
# View all processes running on the host and look for passwords, tokens, keys, etc. 
# Check out that clear text password in the ps output below! 

ps -aux
...omitted for brevity...
root     2123072  0.0  0.0   3732  2868 ?        Ss   21:00   0:00 /bin/bash -c while true; do ./my-program --grafana-uername=admin --grafana-password=admin; sleep 10;done
...omitted for brevity...

# Also, you can also kill any process, but don't do that in production :)
```
# Remove pod
```
kubectl  delete -f pod-hostpid-only.yaml 
```