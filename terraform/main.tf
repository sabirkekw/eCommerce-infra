# 1. Создаем сеть и подсеть
resource "yandex_vpc_network" "ecommerce_network" {
  name = "ecommerce-network"
}

resource "yandex_vpc_subnet" "ecommerce_subnet" {
  name           = "ecommerce-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ecommerce_network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# 2. Создаем сервисный аккаунт для кластера
resource "yandex_iam_service_account" "k8s_sa" {
  name = "k8s-admin-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_role" {
  folder_id = "b1g007jntjr83sfhob8m"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# 3. Сам Managed Kubernetes кластер
resource "yandex_kubernetes_cluster" "ecommerce_cluster" {
  name       = "ecommerce-cluster"
  network_id = yandex_vpc_network.ecommerce_network.id
  
  master {
    zonal {
      zone      = yandex_vpc_subnet.ecommerce_subnet.zone
      subnet_id = yandex_vpc_subnet.ecommerce_subnet.id
    }
    public_ip = true # Чтобы мы могли управлять им снаружи
  }
  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
  depends_on = [yandex_resourcemanager_folder_iam_member.k8s_sa_role]
}

# 4. Группа узлов (Воркеры) - ЭКОНОМНЫЙ ВАРИАНТ
resource "yandex_kubernetes_node_group" "ecommerce_nodes" {
  cluster_id = yandex_kubernetes_cluster.ecommerce_cluster.id
  name       = "ecommerce-nodes"
  instance_template {
    metadata = {
      "ssh-keys" = file("/home/sabirkekw/.ssh/yandexcloud/pubkey")
    }
    platform_id = "standard-v2"
    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.ecommerce_subnet.id]
    }
    resources {
      memory        = 4   # 4 ГБ оперативной памяти
      cores         = 2   # 2 виртуальных ядра
      core_fraction = 20  # Ограничиваем гарантированную мощность CPU до 20% (огромная экономия)
    }
    boot_disk {
      type = "network-hdd"
      size = 30
    }
    scheduling_policy {
      preemptible = true # Делаем ноду прерываемой (минус ~70-80% от стоимости)
    }
  }
  
  scale_policy {
    fixed_scale {
      size = 1 # Снижаем количество нод до 1
    }
  }
  
  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}