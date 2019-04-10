variable "hcloud_token" {}
variable "hcloud_ssh_key" {}
variable "transip_account_name" {}
variable "transip_private_key" {}
variable "docker_org" {}
variable "domain" {}
variable "subdomain" {}
variable "project" {
  default = "dashboard"
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = "${var.hcloud_token}"
}

provider "transip" {
  account_name = "${var.transip_account_name}"
  private_key = "${var.transip_private_key}"
}

data "transip_domain" "domain" {
  name = "${var.domain}"
}

data "template_file" "cloud-init" {
  template = "${file("cloud-init.yaml.tpl")}"
  vars {
    realm = "${var.subdomain}.${var.domain}"
    project = "${var.project}"
    image = "${var.docker_org}/${var.project}"
  }
}

# Create a server
# configure invalid ssh key to prevent root password mails
resource "hcloud_ssh_key" "default" {
  name = "invalid-for-provisioning"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCjcBHiHBNNUQMVrOXt2h+n+e/02kEQ/YQoZNwhlqTabR5J9u2PiQmq1J+G9PfQaENAXSGEnUpYZXyMf9cpuFkeLpcpDw4ujBODD6aif12fd5KJFw+kDNAH2iNXD+2brrPc85m2XfQce6+MAvN0k+gYLByjwDL3zqcGj4Zxy9Sq+2cUD5RmXe2QnpQ30BxiOC9E3/BOk/DJolraqd2E51B6/gwI+kUcf0EhPZIkDbkw2yPtJTdUZ7iOIq2s3wI6w42SfKTmyMQN26MvGygHAIE7crm2TP/hgOrhMbT8fCzFdQmsjD9bf1BwiH8atVO0O8zHAkFX73MwIDc/KzUy0G6T"
}
resource "hcloud_server" "server" {
  count       = 1
  name        = "${var.project}-${count.index}"
  image       = "ubuntu-18.04"
  server_type = "cx31"
  user_data   = "${data.template_file.cloud-init.rendered}"
  ssh_keys    = ["${hcloud_ssh_key.default.name}"]
}

resource "transip_dns_record" "dashboard_v4" {
  count = 1
  domain = "${data.transip_domain.domain.name}"
  type = "A"
  name = "${var.project}.${var.subdomain}"
  expire = 60
  content = ["${hcloud_server.server.ipv4_address}"]
}

resource "transip_dns_record" "dashboard_v6" {
  count = 1
  domain = "${data.transip_domain.domain.name}"
  type = "AAAA"
  name = "${var.project}.${var.subdomain}"
  expire = 60
  # suffix '1' as ipv6_address is broken until next major release
  # https://github.com/terraform-providers/terraform-provider-hcloud/issues/39
  content = ["${hcloud_server.server.ipv6_address}1"]
}

output "ip" {
  value = "${hcloud_server.server.ipv4_address}"
}
output "ip6" {
  value = "${hcloud_server.server.ipv6_address}1"
}

output "hostname" {
  value = "${var.project}.${var.subdomain}.${var.domain}"
}

output "http" {
  value = "https://${var.project}.${var.subdomain}.${var.domain}"
}

output "progress" {
  value = "while sleep 1; ssh ${hcloud_server.server.ipv4_address} tail -f /var/log/cloud-init-output.log; end"
}