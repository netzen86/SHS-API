terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "../../key.json"
  folder_id                = "b1g5tv4fsuuk2l9gvd1p"
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "nz-net" {
  name = "nz-net"
}

resource "yandex_vpc_subnet" "nz-net" {
  name           = "nz-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.nz-net.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}


# resource "yandex_container_registry" "nz-registry" {
#   name = "nz-registry"
# }

locals {
  folder_id = "b1g5tv4fsuuk2l9gvd1p"
  service-accounts = toset([
    "catgpt-container",
  ])
  catgpt-container-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
}

resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-container" {
  for_each  = local.catgpt-container-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-container"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}
resource "yandex_compute_instance" "catgpt-1" {
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-container"].id
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.nz-net.id
    nat       = true
  }
  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "30"
      image_id = data.yandex_compute_image.coi.id
    }
  }
  metadata = {
    docker-compose = file("${path.module}/docker-compose.yaml")
    user-data = "${file("${path.module}/cloud_config.yaml")}"
  }
}

resource "yandex_compute_instance" "catgpt-2" {
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-container"].id
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  scheduling_policy {
    preemptible = true
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.nz-net.id
    nat       = true
  }
  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "30"
      image_id = data.yandex_compute_image.coi.id
    }
  }
  metadata = {
    docker-compose = file("${path.module}/docker-compose.yaml")
    user-data = "${file("${path.module}/cloud_config.yaml")}"
  }
}

resource "yandex_lb_target_group" "nz-tg" {
  name      = "nz-tg"
  region_id = "ru-central1"

  target {
    subnet_id = "${yandex_vpc_subnet.nz-net.id}"
    address   = "${yandex_compute_instance.catgpt-1.network_interface.0.ip_address}"
  }
  target {
    subnet_id = "${yandex_vpc_subnet.nz-net.id}"
    address   = "${yandex_compute_instance.catgpt-2.network_interface.0.ip_address}"
  }
}


resource "yandex_lb_network_load_balancer" "nz-lb" {
  name = "nz-lb"
  deletion_protection = "false"
  listener {
    name = "nz-list"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = "${yandex_lb_target_group.nz-tg.id}"
    healthcheck {
      name = "nz-tg"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
