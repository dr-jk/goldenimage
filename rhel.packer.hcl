
variable "image_name" {
  type        = string
  description = "The family name of the image that is to be generated"
}

variable "project_id" {
  type        = string
  description = "The GCP project id to build the temporary VM in"
}

variable "region" {
  type        = string
  description = "The GCP region to launch the temporary VM in"
}

variable "zone" {
  type        = string
  description = "The GCP zone to launch the temporary VM in"
}

variable "network" {
  type        = string
  description = "The GCP network the VM is to be connected to"
}

variable "subnetwork" {
  type        = string
  description = "The GCP subnet the VM is to be connected to"
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type to use"
}

variable "compute_engine_sva" {
  type        = string
  description = "The service accoun to use on for the temporary VM.  This needs access to the Secret Manager and install media storage bucket"
}

locals {
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  image_description = "Golden Image built with Packer on rhel"
}


variable "source_image_name" {
  type        = string
  description = "The family name of the  source image"
}

variable "disk_size" {
  type    = string
  default = "50"
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "qualys_agent_activation_id" {
  type    = string
  default = ""
}

variable "qualys_agent_customer_id" {
  type    = string
  default = ""
}

variable "qualys_agent_server_uri" {
  type    = string
  default = ""
}

variable "sentinelone_agent_token" {
  type    = string
  default = ""
}

variable "otel_api_token" {
  type    = string
  default = ""
}

variable "dynatrace_reg_token" {
  type    = string
  default = ""
}

source "googlecompute" "gcp_rhel" {
  project_id              = var.project_id
  source_image            = var.source_image_name
  zone                    = var.zone
  enable_secure_boot      = true
  communicator            = "ssh"
  disk_size               = var.disk_size
  disk_type               = var.disk_type
  image_family            = "rhel"
  image_name              = "${var.image_name}-${local.timestamp}"
  image_description       = local.image_description
  image_storage_locations = [var.region]
  machine_type            = var.machine_type
  service_account_email   = var.serviceAccount
  scopes                  = ["https://www.googleapis.com/auth/cloud-platform"]
  omit_external_ip        = true
  use_internal_ip         = true
  network                 = var.network
  subnetwork              = var.subnetwork
  tags                    = ["packer-ssh"]
  ssh_port                = 22
  ssh_username            = "rhel"
  ssh_timeout             = "1m"
}

build {
  sources = ["source "googlecompute" "gcp_rhel"]
  
  provisioner "file" {
    source       = "config.yaml.template"
    destination = "/tmp/config.yaml.template"
  }
  provisioner "shell" {
    script       = "images/scripts/script.sh"
    pause_before = "10s"
    timeout      = "300s"
    environment_vars = [
      "QUALYS_AGENT_ACTIVATION_ID=${var.qualys_agent_activation_id}",
      "QUALYS_AGENT_CUSTOMER_ID=${var.qualys_agent_customer_id}",
      "QUALYS_AGENT_SERVER_URI=${var.qualys_agent_server_uri}",
      "SENTINELONE_AGENT_TOKEN=${var.sentinelone_agent_token}",
      "DYNATRACE_REG_TOKEN=${var.dynatrace_reg_token}",
      "OTEL_API_TOKEN=${var.otel_api_token}"
    ]
  }
  provisioner "shell" {
    script       = "/images/rhel/scripts/cis-harden.sh"
    pause_before = "10s"
    timeout      = "300s"
  }
}
