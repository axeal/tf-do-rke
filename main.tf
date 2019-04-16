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
  name      = "${var.prefix}-rke-${count.index}-all"
  region    = "${var.region}"
  size      = "${var.all_size}"
  user_data = "${data.template_file.userdata.rendered}"
  ssh_keys  = "${var.ssh_keys}"
}

data "template_file" "node" {
  template = "${file("files/node.yml.tmpl")}"
  count    = "${var.count_all_nodes}"
  vars = {
    public_ip  = "${digitalocean_droplet.rke-all.*.ipv4_address[count.index]}"
  }
}

data "template_file" "nodes" {
  template = "${file("files/nodes.yml.tmpl")}"
  vars {
    nodes = "${join("",data.template_file.node.*.rendered)}"
  }
}

resource "local_file" "rke-config" {
  content  = "${data.template_file.nodes.rendered}"
  filename = "${path.module}/rancher-cluster.yml"
}
