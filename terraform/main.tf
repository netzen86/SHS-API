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
  folder_id   = "b1g5tv4fsuuk2l9gvd1p"
  registry_id = "crpbccj0cfhnv6t6ocnd"
  service-accounts = toset([
    "shs-container",
    "shs-ig-sa"
  ])
  shs-container-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
  shs-ig-sa-roles = toset([
    "compute.editor",
    "load-balancer.admin",
    "iam.serviceAccounts.user",
    "vpc.publicAdmin",
    "vpc.user",
  ])
}

resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = each.key
}

resource "yandex_resourcemanager_folder_iam_member" "shs-container-roles" {
  for_each  = local.shs-container-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["shs-container"].id}"
  role      = each.key
}

resource "yandex_resourcemanager_folder_iam_member" "shs-ig-sa-roles" {
  for_each  = local.shs-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["shs-ig-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

data "external" "env" {
  program = ["${path.module}/env.sh"]
}

output "env" {
  value = data.external.env.result
}

resource "yandex_compute_instance_group" "db" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.shs-ig-sa-roles
  ]
  name               = "db"
  service_account_id = yandex_iam_service_account.service-accounts["shs-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 0
    max_creating    = 1
    max_expansion   = 2
    max_deleting    = 1
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["shs-container"].id
    resources {
      cores         = 4
      memory        = 8
      core_fraction = 20
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
        "${path.module}/../db/docker-compose.yaml",
        {
          registry_id       = "${local.registry_id}",
          folder_id         = "${local.folder_id}",
          POSTGRES_DB       = "${data.external.env.result["POSTGRES_DB"]}",
          POSTGRES_USER     = "${data.external.env.result["POSTGRES_USER"]}",
          POSTGRES_PASSWORD = "${data.external.env.result["POSTGRES_PASSWORD"]}",
        }
      )
      user-data = "${file("${path.module}/../db/cloud_config.yaml")}"
    }
  }
}

data "yandex_compute_instance_group" "db" {
  instance_group_id = yandex_compute_instance_group.db.id
}

resource "yandex_compute_instance_group" "shs" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.shs-ig-sa-roles,
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
  health_check {
    interval            = 30
    timeout             = 10
    unhealthy_threshold = 5
    healthy_threshold   = 3
    http_options {
      port = 80
      path = "/ping"
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["shs-container"].id
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
        "${path.module}/../shs/docker-compose.yaml",
        {
          registry_id = "${local.registry_id}",
          folder_id   = "${local.folder_id}",
        }
      )
      user-data = templatefile(
        "${path.module}/../shs/cloud_config.yaml",
        {
          db_address        = "${data.yandex_compute_instance_group.db.instances.0.network_interface.0.ip_address}"
          POSTGRES_DB       = "${data.external.env.result["POSTGRES_DB"]}",
          POSTGRES_USER     = "${data.external.env.result["POSTGRES_USER"]}",
          POSTGRES_PASSWORD = "${data.external.env.result["POSTGRES_PASSWORD"]}",

        }
      )
    }
  }
  # load_balancer {
  #   target_group_name = "shs"
  # }
}

data "yandex_compute_instance_group" "shs" {
  instance_group_id = yandex_compute_instance_group.shs.id
}

resource "yandex_compute_instance_group" "openresty" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.shs-ig-sa-roles
  ]
  name               = "openresty"
  service_account_id = yandex_iam_service_account.service-accounts["shs-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
  health_check {
    interval            = 30
    timeout             = 10
    unhealthy_threshold = 5
    healthy_threshold   = 3
    http_options {
      port = 80
      path = "/nginx-status"
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["shs-container"].id
    resources {
      cores         = 4
      memory        = 4
      core_fraction = 20
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
        "${path.module}/../openresty/docker-compose.yaml",
        {
          registry_id = "${local.registry_id}",
          folder_id   = "${local.folder_id}",
        }
      )
      user-data = templatefile(
        "${path.module}/../openresty/cloud_config.yaml",
        {
          shs_address_0 = "${data.yandex_compute_instance_group.shs.instances.0.network_interface.0.ip_address}"
          shs_address_1 = "${data.yandex_compute_instance_group.shs.instances.1.network_interface.0.ip_address}"
          fullchain     = "${data.external.env.result["fullchain"]}"
          privkey       = "${data.external.env.result["privkey"]}"
        }
      )
    }
  }
}

# resource "yandex_lb_network_load_balancer" "lb-shs" {
#   name = "shs"
#   listener {
#     name        = "shs-listener"
#     port        = 80
#     target_port = 80
#     external_address_spec {
#       ip_version = "ipv4"
#     }
#   }

#   attached_target_group {
#     target_group_id = yandex_compute_instance_group.shs.load_balancer[0].target_group_id

#     healthcheck {
#       name = "http"
#       http_options {
#         port = 80
#         path = "/ping"
#       }
#     }
#   }
# }