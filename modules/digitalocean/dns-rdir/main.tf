terraform {
  required_version = ">= 0.10.0"
}

resource "random_id" "server" {
  count = "${var.count}"
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  count = "${var.count}"
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "digitalocean_ssh_key" "ssh_key" {
  count = "${var.count}"
  name  = "dns-rdir-key-${random_id.server.*.hex[count.index]}"
  public_key = "${tls_private_key.ssh.*.public_key_openssh[count.index]}"
}

resource "digitalocean_droplet" "dns-rdir" {
  count = "${var.count}"
  image = "debian-9-x64"
  name = "dns-rdir-${random_id.server.*.hex[count.index]}"
  region = "${var.available_regions[element(var.regions, count.index)]}"
  ssh_keys = ["${digitalocean_ssh_key.ssh_key.*.id[count.index]}"]
  size = "${var.size}"

  provisioner "remote-exec" {
    inline = [
        "apt-get update",
        "apt-get install -y tmux socat",
        "tmux new -d \"socat udp4-recvfrom:53,reuseaddr,fork udp4-sendto:${element(var.redirect_to, count.index)}\""
    ]

    connection {
        type = "ssh"
        user = "root"
        private_key = "${tls_private_key.ssh.*.private_key_pem[count.index]}"
    }
  }

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh.*.private_key_pem[count.index]}\" > ./ssh_keys/dns_rdir_${self.ipv4_address} && echo \"${tls_private_key.ssh.*.public_key_openssh[count.index]}\" > ./ssh_keys/dns_rdir_${self.ipv4_address}.pub" 
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "rm ./ssh_keys/dns_rdir_${self.ipv4_address}*"
  }

}