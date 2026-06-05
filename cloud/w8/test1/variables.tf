variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "game-store-k8s"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "app_port" {
  type    = number
  default = 30080
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig used by the Kubernetes provider."
  default     = "~/.kube/config"
}

variable "enable_kubernetes_provider_resource" {
  type        = bool
  description = "Create a small ConfigMap with the Kubernetes provider when kubeconfig_path points to a reachable cluster."
  default     = false
}

variable "kubernetes_provider_namespace" {
  type        = string
  description = "Namespace used by the Kubernetes provider proof ConfigMap."
  default     = "default"
}

variable "common_tags" {
  type = map(string)

  default = {
    Environment = "dev"
    Application = "game-store-k8s"
    Owner       = "nghia"
    ManagedBy   = "terraform"
  }
}
