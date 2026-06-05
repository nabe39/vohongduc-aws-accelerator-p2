resource "kubernetes_config_map_v1" "provider_wire_proof" {
  count = var.enable_kubernetes_provider_resource ? 1 : 0

  metadata {
    name      = "terraform-provider-wire-proof"
    namespace = var.kubernetes_provider_namespace

    labels = {
      app        = "game-store"
      managed-by = "terraform"
      provider   = "kubernetes"
    }
  }

  data = {
    managed_by = "terraform"
    provider   = "hashicorp/kubernetes"
    purpose    = "prove that the second Terraform provider manages a real Kubernetes resource"
  }

  depends_on = [
    aws_instance.k8s
  ]
}
