provider "openstack" {}

variable "private_key" {
  default = "/root/.ssh/id_rsa-terraform_cds"
}

variable "public_key" {
  default = "/root/.ssh/id_rsa-terraform_cds.pub"
}

variable "ssh_user" {
  default = "ubuntu"
}

resource "null_resource" "generate-sshkey" {
    provisioner "local-exec" {
        command = "yes y | ssh-keygen -b 4096 -t rsa -C 'terraform_cds' -N '' -f ${var.private_key}"
    }
}

resource "openstack_compute_keypair_v2" "terraform-cds-keypair" {
  name       = "terraform-cds-keypair"
  public_key = "${file(var.public_key)}"
  depends_on = ["null_resource.generate-sshkey"]
}

resource "openstack_networking_network_v2" "internal" {
  name           = "internal"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "internal" {
  name       = "internal"
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr       = "10.240.0.0/24"
  ip_version = 4
}

resource "openstack_compute_secgroup_v2" "terraform-cds-allow-external" {
  name        = "terraform-cds-allow-external"
  description = "permitted inbound external traffic"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 5432
    to_port     = 5432
    ip_protocol = "tcp"
    cidr        = "10.240.0.0/24"
  }

  rule {
    from_port   = 2015
    to_port     = 2015
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 8081
    to_port     = 8081
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

}

resource "openstack_blockstorage_volume_v2" "cds-postgresql-data" {
  region      = "US-EAST-VA-1"
  name        = "cds-postgresql-data"
  description = "data volume for cds postgresql"
  size        = 100
}

data "openstack_images_image_v2" "ubuntu_18_04" {
  name = "Ubuntu 18.04"
  most_recent = true
}

data "openstack_compute_flavor_v2" "s1-2" {
  name = "s1-4"
}

resource "openstack_compute_instance_v2" "cds-postgresql" {
  name            = "cds-postgresql"
  image_id        = "${data.openstack_images_image_v2.ubuntu_18_04.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.s1-2.id}"
  key_pair        = "${openstack_compute_keypair_v2.terraform-cds-keypair.name}"
  security_groups = ["${openstack_compute_secgroup_v2.terraform-cds-allow-external.name}"]

  network {
    name = "Ext-Net",
  }

  network {
    name = "${openstack_networking_network_v2.internal.name}"
    fixed_ip_v4 = "10.240.0.90"
  }

  metadata {
    terraform-cds = "postgresql"
  }

  provisioner "file" {
    source      = "files/cds-postgresql/cds-postgresql-ens4.yaml"
    destination = "/tmp/01-ens4.yaml"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "file" {
    source      = "${var.public_key}"
    destination = "/tmp/authorized_keys"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/01-ens4.yaml /etc/netplan/01-ens4.yaml",
      "sudo netplan apply",
      "sudo mv /tmp/authorized_keys /root/.ssh/authorized_keys",
      "sudo chmod 600 /root/.ssh/authorized_keys",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

}

resource "openstack_compute_volume_attach_v2" "cds-postgresql-volume-attach" {
  instance_id = "${openstack_compute_instance_v2.cds-postgresql.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.cds-postgresql-data.id}"
}

resource "openstack_compute_instance_v2" "cds-engine" {
  name            = "cds-engine"
  image_id        = "${data.openstack_images_image_v2.ubuntu_18_04.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.s1-2.id}"
  key_pair        = "${openstack_compute_keypair_v2.terraform-cds-keypair.name}"
  security_groups = ["${openstack_compute_secgroup_v2.terraform-cds-allow-external.name}"]

  network {
    name = "Ext-Net",
  }

  network {
    name = "${openstack_networking_network_v2.internal.name}"
    fixed_ip_v4 = "10.240.0.91"
  }

  metadata {
    terraform-cds = "haproxy"
  }

  provisioner "file" {
    source      = "files/cds-engine/cds-engine-ens4.yaml"
    destination = "/tmp/01-ens4.yaml"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/01-ens4.yaml /etc/netplan/01-ens4.yaml",
      "sudo netplan apply",
      "sudo apt-get install haproxy -y",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
    }
  }
}

resource "null_resource" "create_hosts_entries" {
    provisioner "local-exec" {
        command = "scripts/generate_hosts.sh"
    }
    depends_on = ["openstack_compute_instance_v2.cds-postgresql", "openstack_compute_instance_v2.cds-engine"]
}

resource "null_resource" "install_postgresql" {

  provisioner "file" {
    source      = "scripts/cds-postgresql/install_postgresql.sh"
    destination = "/tmp/install_postgresql.sh"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-postgresql.access_ip_v4}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/install_postgresql.sh",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-postgresql.access_ip_v4}"
    }
  }
  depends_on = ["openstack_compute_volume_attach_v2.cds-postgresql-volume-attach"]
}

resource "null_resource" "install_cds_and_redis" {

  provisioner "file" {
    source      = "scripts/cds-engine/install_cds.sh"
    destination = "/tmp/install_cds.sh"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-engine.access_ip_v4}"
    }
  }

  provisioner "file" {
    source      = "scripts/cds-engine/install_redis.sh"
    destination = "/tmp/install_redis.sh"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-engine.access_ip_v4}"
    }
  }

  provisioner "file" {
    source      = "files/cds-engine/"
    destination = "/tmp/"

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-engine.access_ip_v4}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/install_cds.sh",
      "sudo bash /tmp/install_redis.sh",
      "sudo chmod 755 /tmp/cds-*.service",
      "sudo chown root:root /tmp/cds-*.service",
      "sudo mv /tmp/cds-*.service /etc/systemd/system/",
      "sudo mv /tmp/conf.toml /opt/cds/conf.toml",
      "for service in $(ls /etc/systemd/system/cds-*.service |xargs -n 1 basename); do echo $service; sudo systemctl enable $service; sudo systemctl start $service; done",
    ]
    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key)}"
      host        = "${openstack_compute_instance_v2.cds-engine.access_ip_v4}"
    }
  }
  depends_on = ["null_resource.install_postgresql"]

}
