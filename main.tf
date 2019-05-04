# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = "${var.do_token}"
}

data "template_file" "userdata" {
  template = "${file("files/userdata")}"

  vars {
    docker_version      = "${var.docker_version}"
  }
}

resource "digitalocean_droplet" "rke-all" {
  count     = "${var.count_all_nodes}"
  image     = "${var.image}"
  name      = "${var.prefix}-rke-all-${count.index}"
  region    = "${var.region}"
  size      = "${var.all_size}"
  user_data = "${data.template_file.userdata.rendered}"
  ssh_keys  = "${var.ssh_keys}"
}

resource "digitalocean_droplet" "rke-etcd" {
  count     = "${var.count_etcd_nodes}"
  image     = "${var.image}"
  name      = "${var.prefix}-rke-etcd-${count.index}"
  region    = "${var.region}"
  size      = "${var.etcd_size}"
  user_data = "${data.template_file.userdata.rendered}"
  ssh_keys  = "${var.ssh_keys}"
}

resource "digitalocean_droplet" "rke-controlplane" {
  count     = "${var.count_controlplane_nodes}"
  image     = "${var.image}"
  name      = "${var.prefix}-rke-controlplane-${count.index}"
  region    = "${var.region}"
  size      = "${var.controlplane_size}"
  user_data = "${data.template_file.userdata.rendered}"
  ssh_keys  = "${var.ssh_keys}"
}

resource "digitalocean_droplet" "rke-worker" {
  count     = "${var.count_worker_nodes}"
  image     = "${var.image}"
  name      = "${var.prefix}-rke-worker-${count.index}"
  region    = "${var.region}"
  size      = "${var.worker_size}"
  user_data = "${data.template_file.userdata.rendered}"
  ssh_keys  = "${var.ssh_keys}"
}

data "template_file" "all_nodes" {
  template = "${file("files/node.yml.tmpl")}"
  count    = "${var.count_all_nodes}"
  vars = {
    public_ip  = "${digitalocean_droplet.rke-all.*.ipv4_address[count.index]}"
    roles       = "[controlplane,worker,etcd]"
  }
}

data "template_file" "etcd_nodes" {
  template = "${file("files/node.yml.tmpl")}"
  count    = "${var.count_etcd_nodes}"
  vars = {
    public_ip  = "${digitalocean_droplet.rke-etcd.*.ipv4_address[count.index]}"
    roles       = "[etcd]"
  }
}

data "template_file" "controlplane_nodes" {
  template = "${file("files/node.yml.tmpl")}"
  count    = "${var.count_controlplane_nodes}"
  vars = {
    public_ip  = "${digitalocean_droplet.rke-controlplane.*.ipv4_address[count.index]}"
    roles       = "[controlplane]"
  }
}

data "template_file" "worker_nodes" {
  template = "${file("files/node.yml.tmpl")}"
  count    = "${var.count_worker_nodes}"
  vars = {
    public_ip  = "${digitalocean_droplet.rke-worker.*.ipv4_address[count.index]}"
    roles       = "[worker]"
  }
}

data "template_file" "nodes" {
  template = "${file("files/nodes.yml.tmpl")}"
  vars {
    nodes = "${chomp(join("",list(join("",data.template_file.all_nodes.*.rendered),join("",data.template_file.etcd_nodes.*.rendered),join("",data.template_file.controlplane_nodes.*.rendered),join("",data.template_file.worker_nodes.*.rendered))))}"
  }
}

resource "local_file" "rke-config" {
  content  = "${data.template_file.nodes.rendered}"
  filename = "${path.module}/rancher-cluster.yml"
}
