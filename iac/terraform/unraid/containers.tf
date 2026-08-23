###############################################################################
# Unraid Docker Containers
# Host: Mercado (VLAN 1 (Management)) · Unraid 7.2.4
# Discovered: 2026-04-11
#
# Import syntax:
#   terraform import docker_container.jellyfin $(docker inspect -f '{{.Id}}' jellyfin)
#   (see import.ps1 for SSH-based import helper)
###############################################################################

# ---------------------------------------------------------------------------
# audiobookshelf  [RUNNING]
# Self-hosted audiobook and podcast server
# Port mapping: host 13378 → container 80
# ---------------------------------------------------------------------------
resource "docker_container" "audiobookshelf" {
  name    = "audiobookshelf"
  image   = docker_image.audiobookshelf.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = 13378
    protocol = "tcp"
  }

  volumes {
    host_path      = "${var.appdata_path}/audiobookshelf/config"
    container_path = "/config"
  }

  volumes {
    host_path      = "${var.appdata_path}/audiobookshelf/metadata"
    container_path = "/metadata"
  }

  volumes {
    host_path      = "${var.media_path}/audiobooks"
    container_path = "/audiobooks"
  }
}

resource "docker_image" "audiobookshelf" {
  name         = "ghcr.io/advplyr/audiobookshelf:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# binhex-official-pihole  [RUNNING]
# Pi-hole DNS sinkhole — macvlan on br0 / VLAN 1 (Management)
# ---------------------------------------------------------------------------
resource "docker_container" "pihole" {
  name         = "binhex-official-pihole"
  image        = docker_image.pihole.image_id
  restart      = "unless-stopped"
  network_mode = "br0"

  # Pi-hole requires a static IP on the LAN for DNS to work
  # Set in Unraid Docker template as macro network IP = VLAN 1 (Management)

  volumes {
    host_path      = "${var.appdata_path}/pihole/pihole"
    container_path = "/etc/pihole"
  }

  volumes {
    host_path      = "${var.appdata_path}/pihole/dnsmasq.d"
    container_path = "/etc/dnsmasq.d"
  }

  env = [
    "TZ=America/Los_Angeles",
    "WEBPASSWORD=changeme", # change after deployment
  ]
}

resource "docker_image" "pihole" {
  name         = "pihole/pihole:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# heimdall  [RUNNING]
# Application links dashboard
# Port mapping: host 8088 → container 80
# ---------------------------------------------------------------------------
resource "docker_container" "heimdall" {
  name    = "heimdall"
  image   = docker_image.heimdall.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = 8088
    protocol = "tcp"
  }

  volumes {
    host_path      = "${var.appdata_path}/heimdall"
    container_path = "/config"
  }
}

resource "docker_image" "heimdall" {
  name         = "ghcr.io/linuxserver/heimdall:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# Jellyfin  [RUNNING]
# Open-source media server — host network
# ---------------------------------------------------------------------------
resource "docker_container" "jellyfin" {
  name         = "Jellyfin"
  image        = docker_image.jellyfin.image_id
  restart      = "unless-stopped"
  network_mode = "host"

  volumes {
    host_path      = "${var.appdata_path}/jellyfin"
    container_path = "/config"
  }

  volumes {
    host_path      = "${var.media_path}/TVShows"
    container_path = "/data/tvshows"
  }

  volumes {
    host_path      = "${var.media_path}/Movies"
    container_path = "/data/movies"
  }
}

resource "docker_image" "jellyfin" {
  name         = "jellyfin/jellyfin:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# MariaDB-Official  [RUNNING]
# MySQL-compatible relational database
# Port mapping: host 3306 → container 3306
# ---------------------------------------------------------------------------
resource "docker_container" "mariadb" {
  name    = "MariaDB-Official"
  image   = docker_image.mariadb.image_id
  restart = "unless-stopped"

  ports {
    internal = 3306
    external = 3306
    protocol = "tcp"
  }

  volumes {
    host_path      = "${var.appdata_path}/mariadb/data"
    container_path = "/var/lib/mysql"
  }

  volumes {
    host_path      = "${var.appdata_path}/mariadb/conf.d"
    container_path = "/etc/mysql/conf.d"
  }

  env = [
    "MYSQL_ROOT_PASSWORD=changeme", # set a strong password
    "TZ=America/Los_Angeles",
  ]
}

resource "docker_image" "mariadb" {
  name         = "mariadb:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# NginxProxyManager  [RUNNING]
# Reverse proxy with Let's Encrypt GUI
# Ports: 18443 (HTTPS), 1880 (HTTP), 7818 (admin UI)
# ---------------------------------------------------------------------------
resource "docker_container" "nginx_proxy_manager" {
  name    = "NginxProxyManager"
  image   = docker_image.nginx_proxy_manager.image_id
  restart = "unless-stopped"

  ports {
    internal = 443
    external = 18443
    protocol = "tcp"
  }

  ports {
    internal = 80
    external = 1880
    protocol = "tcp"
  }

  ports {
    internal = 81
    external = 7818
    protocol = "tcp"
  }

  volumes {
    host_path      = "${var.appdata_path}/nginx-proxy-manager"
    container_path = "/config"
  }
}

resource "docker_image" "nginx_proxy_manager" {
  name         = "jc21/nginx-proxy-manager:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# Plex-Media-Server  [RUNNING]
# Plex — host network
# ---------------------------------------------------------------------------
resource "docker_container" "plex" {
  name         = "Plex-Media-Server"
  image        = docker_image.plex.image_id
  restart      = "unless-stopped"
  network_mode = "host"

  volumes {
    host_path      = "${var.appdata_path}/plex"
    container_path = "/config"
  }

  volumes {
    host_path      = "/tmp/plex-transcode"
    container_path = "/transcode"
  }

  volumes {
    host_path      = var.media_path
    container_path = "/data"
  }

  env = [
    "PLEX_CLAIM=claim-REPLACE_ME", # get from plex.tv/claim if re-registering
    "TZ=America/Los_Angeles",
  ]
}

resource "docker_image" "plex" {
  name         = "plexinc/pms-docker:latest"
  keep_locally = true
}

# ---------------------------------------------------------------------------
# Unraid-Cloudflared-Tunnel  [RUNNING]
# Cloudflare Zero Trust tunnel daemon
# ---------------------------------------------------------------------------
resource "docker_container" "cloudflared" {
  name    = "Unraid-Cloudflared-Tunnel"
  image   = docker_image.cloudflared.image_id
  restart = "unless-stopped"

  volumes {
    host_path      = "${var.appdata_path}/cloudflared"
    container_path = "/appdata"
  }

  # Tunnel token is stored in the appdata volume as a config file.
  # Set TUNNEL_TOKEN env var or place credentials in the config.
}

resource "docker_image" "cloudflared" {
  name         = "cloudflare/cloudflared:latest"
  keep_locally = true
}

###############################################################################
# STOPPED CONTAINERS
###############################################################################

# macinabox  [STOPPED]
resource "docker_container" "macinabox" {
  name    = "macinabox"
  image   = docker_image.macinabox.image_id
  restart = "no"
  start   = false

  volumes {
    host_path      = "${var.appdata_path}/macinabox"
    container_path = "/config"
  }
}

resource "docker_image" "macinabox" {
  name         = "sickcodes/docker-osx:sonoma"
  keep_locally = true
}

# PostgreSQL_Immich  [STOPPED]
resource "docker_container" "postgres_immich" {
  name    = "PostgreSQL_Immich"
  image   = docker_image.postgres_immich.image_id
  restart = "no"
  start   = false

  ports {
    internal = 5432
    external = 5433
    protocol = "tcp"
  }

  volumes {
    host_path      = "${var.appdata_path}/postgres-immich"
    container_path = "/var/lib/postgresql/data"
  }

  env = [
    "POSTGRES_PASSWORD=changeme",
    "POSTGRES_USER=immich",
    "POSTGRES_DB=immich",
  ]
}

resource "docker_image" "postgres_immich" {
  name         = "tensorchord/pgvecto-rs:pg16-v0.2.0"
  keep_locally = true
}
