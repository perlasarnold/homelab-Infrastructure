###############################################################################
# Unraid Docker Configuration
# Host: Mercado (192.168.1.24) · Unraid 7.2.4
# Provider: kreuzwerker/docker
#
# PREREQUISITE — Enable Docker TCP API on Unraid:
#   Unraid UI → Settings → Docker → Docker custom network → enable
#   Then add this to /etc/docker/daemon.json (via User Scripts):
#     { "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"] }
#   OR use SSH tunnel instead (safer):
#     ssh -L 2375:/var/run/docker.sock root@192.168.1.24 -N
#     Then set docker_host = "tcp://localhost:2375"
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "tcp://${var.unraid_ip}:${var.docker_port}"
}
