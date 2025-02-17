# Создание сети
resource "yandex_vpc_network" "network" {
  name = "lamp-network"
}

# Создание подсети
resource "yandex_vpc_subnet" "subnet" {
  name           = "lamp-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Создание группы безопасности
resource "yandex_vpc_security_group" "lamp_sg" {
  name        = "lamp-security-group"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание Instance Group
resource "yandex_compute_instance_group" "lamp_group" {
  name                = "lamp-instance-group"
  folder_id           = var.folder_id
  service_account_id  = var.service_account_id  
  deletion_protection = false

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = "fd827b91d99psvq5fjit" 
      }
    }

    network_interface {
      network_id = yandex_vpc_network.network.id
      subnet_ids = [yandex_vpc_subnet.subnet.id]
      nat        = true
      security_group_ids = [yandex_vpc_security_group.lamp_sg.id]
    }

    metadata = {
      user-data = <<-EOF
        #cloud-config
        runcmd:
          - apt-get update
          - apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql
          - echo "<html><body><h1>Network Load Balancer</h1><img src='https://storage.yandexcloud.net/${yandex_storage_bucket.my_bucket.bucket}/${yandex_storage_object.my_image.key}'></body></html>" > /var/www/html/index.html
          - systemctl restart apache2
        EOF
      ssh-keys = "ubuntu:${file("/root/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3

    http_options {
      path = "/"
      port = 80
    }
  }
}

# Создание симметричного ключа шифрования
resource "yandex_kms_symmetric_key" "my_key" {
  name              = "my-encryption-key"
  description       = "Encryption key for S3 bucket"
  default_algorithm = "AES_128"
  rotation_period   = "24h"
}

# Создание бакета в Object Storage с шифрованием
resource "yandex_storage_bucket" "my_bucket" {
  bucket = "shvn2025"  # Укажите уникальное имя бакета
  acl    = "public-read"
  folder_id  = var.folder_id  # Укажите ID каталога

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.my_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# Загрузка изображения в бакет
resource "yandex_storage_object" "my_image" {
  bucket = yandex_storage_bucket.my_bucket.bucket
  key    = "image.jpg"  # Имя файла в бакете
  source = "/home/admon/dz-3/image.jpg"  # Укажите путь к изображению на локальной машине
  acl    = "public-read"
  content_type = "image/jpeg"
}

# Создание целевой группы (Target Group)
resource "yandex_lb_target_group" "lamp_target_group" {
  name      = "lamp-target-group"
  region_id = "ru-central1"

  target {
    subnet_id  = yandex_vpc_subnet.subnet.id
    address    = yandex_compute_instance_group.lamp_group.instances[0].network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.subnet.id
    address    = yandex_compute_instance_group.lamp_group.instances[1].network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.subnet.id
    address    = yandex_compute_instance_group.lamp_group.instances[2].network_interface[0].ip_address
  }
}

# Создание Network Load Balancer
resource "yandex_lb_network_load_balancer" "lamp_load_balancer" {
  name = "lamp-network-load-balancer"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.lamp_target_group.id

    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
