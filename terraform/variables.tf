#Список переменных 
variable "cloud_id" {
  type        = string
  default     = "b1g811k1u7vur9c50o56"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  default     = "b1g21imo75hodv3r669v"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "service_account_id" {
  type        = string
  default     = "ajeg5hdrbq9s7kdsk7b9"
  description = "https://yandex.cloud/ru/docs/iam/concepts/users/service-accounts"
}

