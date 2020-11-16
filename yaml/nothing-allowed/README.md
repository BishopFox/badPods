## You have nothing

The pod security policy or admission controller has blocked access to all of the host's namespaces and restricted all capabilities.  **Do not despair**, especially if the target cluster is running in a cloud environment. 

Can your pod access the cloud provider' metadata service?
Is the kubernetes version vulnerable to an exploit, i.e. [CVE-2020-8558](https://github.com/tabbysable/POC-2020-8558)
[pod-priv-only.yaml](pod-priv-only.yaml)

 