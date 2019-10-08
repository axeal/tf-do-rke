#!/bin/bash

kubectl -n kube-system create serviceaccount tiller

kubectl create clusterrolebinding tiller \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:tiller

helm init --service-account tiller

kubectl -n kube-system  rollout status deploy/tiller-deploy

helm install stable/cert-manager \
  --name cert-manager \
  --namespace kube-system \
  --version v0.5.2

kubectl -n kube-system rollout status deploy/cert-manager

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

helm install rancher-stable/rancher \
  --name rancher \
  --namespace cattle-system \
  --set hostname=$1 \
  --version $2
