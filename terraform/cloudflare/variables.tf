variable "zone_id" {
  type = string
}

variable "zone_name" {
  type = string
}

variable "records" {
  type = list(object({
    name = string
    type = string
    value = string
  }))
  
}