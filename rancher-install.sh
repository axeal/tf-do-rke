#!/bin/bash
set -o xtrace
export RANCHER_TLS_SOURCE=rancher
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
      echo "-t, --tls-source=SOURCE    specify tls source for Rancher ingress rancher/letsEncrypt/secret (defaults to rancher)"
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
    -t)
      shift
      if test $# -gt 0; then
        export RANCHER_TLS_SOURCE=$1
      else
        echo "no Rancher tls source specified"
        exit 1
      fi
      shift
      ;;
    --tls-source*)
      export RANCHER_TLS_SOURCE=`echo $1 | sed -e 's/^[^=]*=//g'`
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

if [[ $RANCHER_TLS_SOURCE == "letsEncrypt" ]]; then
  export RANCHER_TLS_STRING="--set ingress.tls.source=letsEncrypt"
elif [[ $RANCHER_TLS_SOURCE == "rancher" ]]; then
  export RANCHER_TLS_STRING=""
elif [[ $RANCHER_TLS_SOURCE == "secret" ]]; then
  export RANCHER_TLS_STRING="--set ingress.tls.source=secret"
else
  echo "Invalid tls source specified, must be one of rancher/letsEncrypt/secret"
  exit 1
fi

export KUBECONFIG=kube_config_cluster.yml

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

kubectl rollout status daemonset -n ingress-nginx nginx-ingress-controller

if [[ $RANCHER_TLS_SOURCE == "rancher" || $RANCHER_TLS_SOURCE == "letsEncrypt" ]]; then

  helm repo add jetstack https://charts.jetstack.io

  helm repo update

  helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.5.1 \
  --set installCRDs=true

  kubectl wait --for=condition=Available -n cert-manager deployment cert-manager-webhook

  helm upgrade --install rancher rancher-stable/rancher \
    --namespace cattle-system \
    --create-namespace \
    --set hostname=$RANCHER_HOSTNAME \
    $RANCHER_TLS_STRING \
    $RANCHER_VERSION_STRING

else

  kubectl create namespace cattle-system
  kubectl -n cattle-system create secret generic tls-ca --from-file=./certs/cacerts.pem
  kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=./certs/cert.pem --key=./certs/key.pem

  helm install rancher rancher-stable/rancher \
    --namespace cattle-system \
    --set hostname=$RANCHER_HOSTNAME \
    $RANCHER_VERSION_STRING \
    $RANCHER_TLS_STRING \
    --set privateCA=true

fi
