variable "do_token" {
}

variable "prefix" {
}

variable "region" {
  default = "fra1"
}

variable "count_all_nodes" {
  default = "1"
}

variable "count_etcd_nodes" {
  default = "0"
}

variable "count_controlplane_nodes" {
  default = "0"
}

variable "count_worker_nodes" {
  default = "0"
}

variable "docker_version" {
  default = "19.03"
}

variable "all_size" {
  default = "s-2vcpu-4gb"
}

variable "etcd_size" {
  default = "s-2vcpu-4gb"
}

variable "controlplane_size" {
  default = "s-2vcpu-4gb"
}

variable "worker_size" {
  default = "s-2vcpu-4gb"
}

variable "image" {
  default = "ubuntu-16-04-x64"
}

variable "ssh_keys" {
  default = []
}

variable "digitalocean_domain" {
}

