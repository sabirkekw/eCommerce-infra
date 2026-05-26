terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone      = "ru-central1-a"
  cloud_id  = "b1gr9684aa550l1b4a53"
  folder_id = "b1g007jntjr83sfhob8m"
}