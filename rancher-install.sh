#!/bin/bash
set -o xtrace
export RANCHER_TLS_SOURCE=self
export RANCHER_VERSION=""
export RANCHER_HOSTNAME=""

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "rancher-install.sh - install Rancher from helm chart into RKE lab"
      echo " "
      echo "rancher-install.sh [options]"
      echo " "
      echo "options:"
      echo "-h, --help                 show help"
      echo "-H, --hostname=HOSTNAME    specify hostname for Rancher"
      echo "-v, --version=VERSION      specify version for Rancher"
      echo "-s, --secret-tls           use secret for Rancher ingress (defaults to self-signed)"
      exit 0
      ;;
    -H)
      shift
      if test $# -gt 0; then
        export RANCHER_HOSTNAME=$1
      else
        echo "no Rancher hostname specified"
        exit 1
      fi
      shift
      ;;
    --hostname*)
      export RANCHER_HOSTNAME=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -v)
      shift
      if test $# -gt 0; then
        export RANCHER_VERSION=$1
      else
        echo "no Rancher version specified"
        exit 1
      fi
      shift
      ;;
    --version*)
      export RANCHER_VERSION=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -s|--secret-tls)
      export RANCHER_TLS_SOURCE=secret
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ $RANCHER_HOSTNAME == "" ]]; then
  echo "no Rancher hostname specified"
  exit 1
fi

if [[ $RANCHER_VERSION == "" ]]; then
  export RANCHER_VERSION_STRING=""
else
  export RANCHER_VERSION_STRING="--version $RANCHER_VERSION"
fi

if [[ $RANCHER_TLS_SOURCE == "self" ]]; then
  export KUBECONFIG=kube_config_cluster.yml

  kubectl -n kube-system create serviceaccount tiller

  kubectl create clusterrolebinding tiller \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller

  helm init --service-account tiller

  kubectl -n kube-system  rollout status deploy/tiller-deploy

  kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml

  kubectl create namespace cert-manager

  kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

  helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.9.1 \
  jetstack/cert-manager

  kubectl -n cert-manager  rollout status deploy/cert-manager

  helm install rancher-stable/rancher \
    --name rancher \
    --namespace cattle-system \
    --set hostname=$RANCHER_HOSTNAME \
    $RANCHER_VERSION_STRING
else
  export KUBECONFIG=kube_config_cluster.yml

  kubectl -n kube-system create serviceaccount tiller

  kubectl create clusterrolebinding tiller \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller

  helm init --service-account tiller

  kubectl -n kube-system  rollout status deploy/tiller-deploy

  kubectl create namespace cattle-system
  kubectl -n cattle-system create secret generic tls-ca --from-file=./certs/cacerts.pem
  kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=./certs/cert.pem --key=./certs/key.pem

  helm install rancher-latest/rancher \
    --name rancher \
    --namespace cattle-system \
    --set hostname=$RANCHER_HOSTNAME \
    $RANCHER_VERSION_STRING \
    --set ingress.tls.source=secret \
    --set privateCA=true
fi
