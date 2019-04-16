variable "do_token" {}

variable "prefix" {}

variable "region" {
  default = "fra1"
}

variable "count_all_nodes" {
  default = "1"
}

variable "docker_version" {
  default = "17.03"
}

variable "all_size" {
  default = "s-2vcpu-4gb"
}

variable "image" {
  default = "ubuntu-16-04-x64"
}

variable "ssh_keys" {
  default = []
}
