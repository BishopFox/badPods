## You can create a pod with only hostIPC

If you only have `hostIPC=true`, you most likely can't do much. What you should do is use the ipcs command inside your hostIPC container to see if there are any ipc resources (shared memory segments, message queues, or semephores). If you find one, you will likely need to create a program that can read them. 

[pod-hostipc-only.yaml](pod-hostipc-only.yaml)

### Create pod
```bash
# Option 1: Create pod from local yaml 
kubectl apply -f pod-hostipc-only.yaml  [-n namespace] 

# Option 2: Create pod from github hosted yaml
kubectl apply -f https://raw.githubusercontent.com/BishopFox/badPods/main/yaml/hostipc-only/pod-hostipc-only.yaml [-n namespace] 
```

### Exec into pod 
```bash
kubectl -n [namespace] exec -it pod-hostipc-only -- bash
```

### Post exploitation 
```bash
# Look for any use of inter-process communication on the host 
ipcs -a
```

Reference: https://opensource.com/article/20/1/inter-process-communication-linux