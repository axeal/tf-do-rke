# Terraform config to launch nodes for an RKE cluster

## Summary

This Terraform setup will:

- Provision Digital Ocean droplets and install the Docker daemon on these
- Create a cluster.yml configuration file containing those droplets to enable provisioning a Kubernetes clusters with [Rancher Kubernetes Engine (RKE)](https://rancher.com/docs/rke/latest/en/)

## Other options

All available options/variables are described in [terraform.tfvars.example](https://github.com/axeal/tf-do-rke/blob/master/terraform.tfvars.example).

## How to use

- Clone this repository
- Move the file `terraform.tfvars.example` to `terraform.tfvars` and edit (see inline explanation)
- Run `terraform init`
- Run `terraform apply`
- Once terraform provisioning has completed you can provision a Kubernetes cluster with RKE `rke up --config cluster.yml`. The RKE binary is required and can be [installed per docs](https://rancher.com/docs/rke/latest/en/installation/)
- When `terraform destroy` is performed, the Kubernetes CLI configuration file `kube_config_cluster.yml` and RKE state file `cluster.rkestate` auto-generated by RKE will be deleted from the directory, if present, alongside the `cluster.yml` created by terraform.
