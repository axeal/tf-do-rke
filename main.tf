# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_account" "do-account" {
}

resource "digitalocean_vpc" "droplets-network" {
  name   = "${var.prefix}-tf-do-rke-droplets-vpc"
  region = var.region
}

resource "time_sleep" "wait_10_seconds_to_destroy_vpc" {
  depends_on       = [digitalocean_vpc.droplets-network]
  destroy_duration = "10s"
}

resource "digitalocean_droplet" "rke-all" {
  depends_on = [time_sleep.wait_10_seconds_to_destroy_vpc]
  count      = var.count_all_nodes
  image      = var.image
  name       = "${var.prefix}-rke-all-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.all_size
  user_data = templatefile("${path.module}/files/userdata", {
    docker_version = var.docker_version
  })
  ssh_keys = var.ssh_keys
  tags     = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-master" {
  depends_on = [time_sleep.wait_10_seconds_to_destroy_vpc]
  count      = var.count_master_nodes
  image      = var.image
  name       = "${var.prefix}-rke-master-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.master_size
  user_data = templatefile("${path.module}/files/userdata", {
    docker_version = var.docker_version
  })
  ssh_keys = var.ssh_keys
  tags     = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-etcd" {
  depends_on = [time_sleep.wait_10_seconds_to_destroy_vpc]
  count      = var.count_etcd_nodes
  image      = var.image
  name       = "${var.prefix}-rke-etcd-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.etcd_size
  user_data = templatefile("${path.module}/files/userdata", {
    docker_version = var.docker_version
  })
  ssh_keys = var.ssh_keys
  tags     = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-controlplane" {
  depends_on = [time_sleep.wait_10_seconds_to_destroy_vpc]
  count      = var.count_controlplane_nodes
  image      = var.image
  name       = "${var.prefix}-rke-controlplane-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.controlplane_size
  user_data = templatefile("${path.module}/files/userdata", {
    docker_version = var.docker_version
  })
  ssh_keys = var.ssh_keys
  tags     = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-worker" {
  depends_on = [time_sleep.wait_10_seconds_to_destroy_vpc]
  count      = var.count_worker_nodes
  image      = var.image
  name       = "${var.prefix}-rke-worker-${count.index}"
  vpc_uuid   = digitalocean_vpc.droplets-network.id
  region     = var.region
  size       = var.worker_size
  user_data = templatefile("${path.module}/files/userdata", {
    docker_version = var.docker_version
  })
  ssh_keys = var.ssh_keys
  tags     = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_record" "dns" {
  domain = var.digitalocean_domain
  type   = "A"
  ttl    = 30
  name   = "${var.prefix}-tf-do-rke"
  value  = var.count_all_nodes > 0 ? digitalocean_droplet.rke-all[0].ipv4_address : digitalocean_droplet.rke-worker[0].ipv4_address
}

resource "local_file" "rke-config" {
  content = templatefile("${path.module}/files/nodes.yml.tmpl", {
    rke-all          = [for node in digitalocean_droplet.rke-all : node.ipv4_address],
    rke-master       = [for node in digitalocean_droplet.rke-master : node.ipv4_address],
    rke-etcd         = [for node in digitalocean_droplet.rke-etcd : node.ipv4_address],
    rke-controlplane = [for node in digitalocean_droplet.rke-controlplane : node.ipv4_address],
    rke-worker       = [for node in digitalocean_droplet.rke-worker : node.ipv4_address],
  })
  filename = "${path.module}/cluster.yml"
}

resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/files/ssh_config.tmpl", {
    prefix           = var.prefix
    rke-all          = [for node in digitalocean_droplet.rke-all : node.ipv4_address],
    rke-master       = [for node in digitalocean_droplet.rke-master : node.ipv4_address],
    rke-etcd         = [for node in digitalocean_droplet.rke-etcd : node.ipv4_address],
    rke-controlplane = [for node in digitalocean_droplet.rke-controlplane : node.ipv4_address],
    rke-worker       = [for node in digitalocean_droplet.rke-worker : node.ipv4_address],
  })
  filename = "${path.module}/ssh_config"
}

resource "null_resource" "rke-state" {
  provisioner "local-exec" {
    when = destroy

    # Remove cluster.rkestate and kube_config_cluster.yml auto-generated by RKE when nodes destroyed
    command = "rm -f cluster.rkestate kube_config_cluster.yml"
  }
}

output "rke-all-nodes" {
  value = var.count_all_nodes > 0 ? [for node in digitalocean_droplet.rke-all : { name = node.name, ip = node.ipv4_address }] : null
}

output "rke-master-nodes" {
  value = var.count_master_nodes > 0 ? [for node in digitalocean_droplet.rke-master : { name = node.name, ip = node.ipv4_address }] : null
}

output "rke-etcd-nodes" {
  value = var.count_etcd_nodes > 0 ? [for node in digitalocean_droplet.rke-etcd : { name = node.name, ip = node.ipv4_address }] : null
}

output "rke-controlplane-nodes" {
  value = var.count_controlplane_nodes > 0 ? [for node in digitalocean_droplet.rke-controlplane : { name = node.name, ip = node.ipv4_address }] : null
}

output "rke-worker-nodes" {
  value = var.count_worker_nodes > 0 ? [for node in digitalocean_droplet.rke-worker : { name = node.name, ip = node.ipv4_address }] : null
}

output "rancher-hostname" {
  value = "${var.prefix}-tf-do-rke.${var.digitalocean_domain}"
}
