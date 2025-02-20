terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.6.8"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Create VM disk images for 3 nodes (1 master + 2 workers)
resource "libvirt_volume" "k8s_vm_disk" {
  count  = 3
  name   = "k8s-vm-${count.index}.qcow2"
  pool   = "default"
  source = "/var/lib/libvirt/images/ubuntu-20.04-server-cloudimg-amd64.img"  # Ensure this image is available locally
  format = "qcow2"
  size   = "2GB"
}

# Cloud-init for the master node
resource "libvirt_cloudinit_disk" "master_init" {
  name      = "master-init.iso"
  user_data = file("cloud-init-master.yaml")
}

# Cloud-init for worker nodes
resource "libvirt_cloudinit_disk" "worker_init" {
  count     = 2
  name      = "worker-init-${count.index}.iso"
  user_data = file("cloud-init-worker.yaml")
}

# Define the master node domain
resource "libvirt_domain" "k8s_master" {
  name   = "k8s-master"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.master_init.id

  disk {
    volume_id = libvirt_volume.k8s_vm_disk[0].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
  }
}

# Define the worker node domains
resource "libvirt_domain" "k8s_worker" {
  count  = 2
  name   = "k8s-worker-${count.index}"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.worker_init[count.index].id

  disk {
    volume_id = libvirt_volume.k8s_vm_disk[count.index + 1].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
  }
}
