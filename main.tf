# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "template_file" "userdata" {
  template = file("files/userdata")

  vars = {
    docker_version = var.docker_version
  }
}

data "digitalocean_account" "do-account" {
}

resource "digitalocean_vpc" "droplets-network" {
  name        = "${var.prefix}-tf-do-rke-droplets-vpc"
  region      = var.region
}

resource "digitalocean_droplet" "rke-all" {
  count              = var.count_all_nodes
  image              = var.image
  name               = "${var.prefix}-rke-all-${count.index}"
  vpc_uuid           = digitalocean_vpc.droplets-network.id
  region             = var.region
  size               = var.all_size
  user_data          = data.template_file.userdata.rendered
  ssh_keys           = var.ssh_keys
  tags               = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-etcd" {
  count              = var.count_etcd_nodes
  image              = var.image
  name               = "${var.prefix}-rke-etcd-${count.index}"
  vpc_uuid           = digitalocean_vpc.droplets-network.id
  region             = var.region
  size               = var.etcd_size
  user_data          = data.template_file.userdata.rendered
  ssh_keys           = var.ssh_keys
  tags               = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-controlplane" {
  count              = var.count_controlplane_nodes
  image              = var.image
  name               = "${var.prefix}-rke-controlplane-${count.index}"
  vpc_uuid           = digitalocean_vpc.droplets-network.id
  region             = var.region
  size               = var.controlplane_size
  user_data          = data.template_file.userdata.rendered
  ssh_keys           = var.ssh_keys
  tags               = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_droplet" "rke-worker" {
  count              = var.count_worker_nodes
  image              = var.image
  name               = "${var.prefix}-rke-worker-${count.index}"
  vpc_uuid           = digitalocean_vpc.droplets-network.id
  region             = var.region
  size               = var.worker_size
  user_data          = data.template_file.userdata.rendered
  ssh_keys           = var.ssh_keys
  tags               = [join("", ["user:", replace(split("@", data.digitalocean_account.do-account.email)[0], ".", "-")])]
}

resource "digitalocean_record" "dns" {
  domain = var.digitalocean_domain
  type   = "A"
  ttl    = 30
  name   = "${var.prefix}-tf-do-rke"
  value  = digitalocean_droplet.rke-all[0].ipv4_address
}

data "template_file" "all_nodes" {
  template = file("files/node.yml.tmpl")
  count    = var.count_all_nodes
  vars = {
    public_ip = digitalocean_droplet.rke-all[count.index].ipv4_address
    roles     = "[controlplane,worker,etcd]"
  }
}

data "template_file" "etcd_nodes" {
  template = file("files/node.yml.tmpl")
  count    = var.count_etcd_nodes
  vars = {
    public_ip = digitalocean_droplet.rke-etcd[count.index].ipv4_address
    roles     = "[etcd]"
  }
}

data "template_file" "controlplane_nodes" {
  template = file("files/node.yml.tmpl")
  count    = var.count_controlplane_nodes
  vars = {
    public_ip = digitalocean_droplet.rke-controlplane[count.index].ipv4_address
    roles     = "[controlplane]"
  }
}

data "template_file" "worker_nodes" {
  template = file("files/node.yml.tmpl")
  count    = var.count_worker_nodes
  vars = {
    public_ip = digitalocean_droplet.rke-worker[count.index].ipv4_address
    roles     = "[worker]"
  }
}

data "template_file" "nodes" {
  template = file("files/nodes.yml.tmpl")
  vars = {
    nodes = chomp(
      join(
        "",
        [
          join("", data.template_file.all_nodes.*.rendered),
          join("", data.template_file.etcd_nodes.*.rendered),
          join("", data.template_file.controlplane_nodes.*.rendered),
          join("", data.template_file.worker_nodes.*.rendered),
        ],
      ),
    )
  }
}

resource "local_file" "rke-config" {
  content  = data.template_file.nodes.rendered
  filename = "${path.module}/cluster.yml"
}

resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/files/ssh_config.tmpl", {
    prefix           = var.prefix
    rke-all          = [for node in digitalocean_droplet.rke-all : node.ipv4_address],
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
  value = [for node in digitalocean_droplet.rke-all : { name = node.name, ip = node.ipv4_address }]
}

output "rke-etcd-nodes" {
  value = [for node in digitalocean_droplet.rke-etcd : { name = node.name, ip = node.ipv4_address }]
}

output "rke-controlplane-nodes" {
  value = [for node in digitalocean_droplet.rke-controlplane : { name = node.name, ip = node.ipv4_address }]
}

output "rke-worker-nodes" {
  value = [for node in digitalocean_droplet.rke-worker : { name = node.name, ip = node.ipv4_address }]
}

output "rancher-hostname" {
  value = "${var.prefix}-tf-do-rke.${var.digitalocean_domain}"
}
