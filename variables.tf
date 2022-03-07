variable "pvt_key" {
  default = "~/.ssh/id_rsa_webodm.pem"
}
variable "pub_key" {
  default = "id_rsa_webodm"
}
variable "pub_key_loc" {
  default = "~/.ssh/id_rsa_webodm.pub"
}
variable "pub_key_data" {
  description = "The contents of the public key are stored in GitHub as a secret"
}
variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "odm-v4"
}
/*variable "resource_group_name" {
  default = "odm-v3"
}*/
variable "location" {
  default = "centralus"
}

variable "vmSize" {
  default = "Standard_D2s_v3"
  #vmSize = "Standard_D4s_v3"
  #vmSize = "Standard_D8s_v3"
}

variable "adminUser" {
  default = "ubuntu"
}
variable "publisher" {
  default = "Canonical"
}
variable "offer" {
  default = "UbuntuServer"
}
variable "sku" {
  default = "18_04-lts-gen2"
}
variable "skuVersion" {
  default = "latest"
}
variable "storageAccountType" {
  default = "Premium_LRS"
}
variable "diskSizeGB" {
  default = "50"
}
