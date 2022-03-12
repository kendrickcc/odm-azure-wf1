variable "repo_name" {
  default = "odm-azure-wf1"
}
variable "repo_owner" {
  default = "kendrickcc"
}
variable "project" {
  default = "test build"
}
variable "pub_key" {
  default = "id_rsa_webodm"
}
variable "pub_key_data" {
  description = "The contents of the public key are stored in GitHub as a secret"
}
variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "odm-v4"
}
variable "location" {
  default = "centralus"
}
variable "webodm_servers" {
  description = "Name(s) of WebODM/ClusterODM server."
  type        = list(string)
  default     = ["webodm"] # i.e. ["webodm","clusterodm"]
}
variable "nodeodm_servers" {
  description = "Names of nodeODM servers"
  type        = list(string)
  default     = ["nodeodm1", "nodeodm2"] # i.e. ["nodeodm1","nodeodm2","nodeodm3"]
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
  default = "100"
}
