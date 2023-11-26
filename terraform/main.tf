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
  registry_id = "crpbccj0cfhnv6t6ocnd"
  service-accounts = toset([
    # "shs-container",
    "shs-ig-sa"
  ])
  # shs-container-roles = toset([
  #   "container-registry.images.puller",
  #   "monitoring.editor",
  # ])
  shs-ig-sa-roles = toset([
    "compute.editor",
    "iam.serviceAccounts.user",
    "vpc.publicAdmin",
    "vpc.user",
  ])
}

resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = each.key
}

# resource "yandex_resourcemanager_folder_iam_member" "shs-container-roles" {
#   for_each  = local.shs-container-roles
#   folder_id = local.folder_id
#   member    = "serviceAccount:${yandex_iam_service_account.service-accounts["shs-container"].id}"
#   role      = each.key
# }

resource "yandex_resourcemanager_folder_iam_member" "shs-ig-sa-roles" {
  for_each  = local.shs-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["shs-ig-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance_group" "shs" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.shs-ig-sa-roles
  ]
  name               = "shs"
  service_account_id = yandex_iam_service_account.service-accounts["shs-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 2
    max_expansion   = 3
    max_deleting    = 2
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["shs-ig-sa"].id
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      # network_id = yandex_vpc_network.nz-net.id
      subnet_ids = ["${yandex_vpc_subnet.nz-net.id}"]
      nat        = true
    }
    boot_disk {
      initialize_params {
        type     = "network-hdd"
        size     = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = templatefile(
        "${path.module}/docker-compose.yaml",
        {
          registry_id = local.registry_id,
        }
      )      
      user-data      = "${file("${path.module}/cloud_config.yaml")}"
    }
  }
}
