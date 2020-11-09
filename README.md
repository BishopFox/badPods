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
ALL | Multiple likely paths to full cluster compromise (all resources in all namespaces) <img width=800/>| Once you create the pod, you can exec into it and you will have root access on the node running your pod. Your best hope is that you can schedule your pod to run on the master node (not possible in a cloud managed environment). Regardless of whether you are on the master node or a worker, you can access the node's kubelet creds, you can create mirror pods in any namespace, and you can access any secret mounted within any pod on the node you are on and use it to gain access to other namespaces. <br> yaml: [pod-everything-allowed](yaml/pod-everything-allowed.yaml)
hostPID + privileged |  Same as above | Same as above <br>yaml:  [pod-priv-and-hostpid](yaml/pod-priv-and-hostpid.yaml)
privileged=true | Same as above | While you will eventually get an interactive shell on the node like in the cases above, you start with non-interactive command execution and you'll have to upgrade it if you want interactive access. The privesc paths are the same as above. <br> yaml: [pod-priv-only](yaml/pod-priv-only.yaml)
Unrestricted hostmount (/) | Same as above | While you don't have access to host process or network namespaces, having access to the full filesystem allows you to perform the same types of privesc paths outlined above. Hunt for tokens from other pods running on the node and hope you find a token associated with a highly privileged service account.  <br>yaml:  [pod-hostnetwork-only](yaml/pod-hostnetwork-only.yaml)
hostpid | Unlikely but possible path to cluster compromise <br> | You can access any secrets visible via ps -aux.  Look for passwords, tokens, keys and use them to privesc within the cluster, to services supported by the cluster, or to services that applications in the cluster are communicating with. It is a long shot, but you might find a kubernetes token or some other authentication material that will allow you to access other namespaces and eventually escalate all the way up to cluster-admin.   You can also kill any process on the node (DOS) <br>yaml:  [pod-hostpid-only](yaml/pod-hostpid-only.yaml)
hostnetwork | Potential path to cluster compromise | Sniff unencrypted traffic on any interface and potentially find service account tokens or other sensitive information <br> Communicate with services that only listen on loopback, etc. <br>yaml:  [pod-hostnetwork-only](yaml/pod-hostnetwork-only.yaml)
hostipc | Not much on its own unless some services on the host are using hostIPC | <br>yaml:  [pod-hostipc-only](yaml/pod-hostipc-only.yaml)


Caveat: There are many kubernetes specific security controls available to administrators that can reduce the impact of pods created with the following privileges. As is always the case with penetration testing, your milage may vary.


# Usage
 Each pod spec in the yamls directory targets a specific attribute or a combination of attributes that expose your cluster to risk. 


















# Remove pods
kubectl -n [namespace] delete -f pod-file-name.yaml