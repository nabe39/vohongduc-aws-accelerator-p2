# --- K8s Bootstrapping waiter ---
resource "terraform_data" "wait_for_k8s" {
  depends_on = [aws_instance.k8s_node]

  provisioner "local-exec" {
    command = "powershell -File ${path.module}/wait_k8s.ps1 ${aws_instance.k8s_node.public_ip} ${aws_instance.k8s_node.id}"
  }

  # Clean up generated kubeconfig on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "powershell -Command \"Remove-Item -Path '${path.module}/kubeconfig_*.yaml' -Force -ErrorAction SilentlyContinue\""
  }
}

# --- Dynamic Kubernetes Provider ---
provider "kubernetes" {
  config_path = terraform_data.wait_for_k8s.id != "" ? "${path.module}/kubeconfig_${aws_instance.k8s_node.id}.yaml" : null
}

# --- Kubernetes ConfigMap for Custom Beautiful Web Page ---
resource "kubernetes_config_map" "web_html" {
  depends_on = [
    aws_route_table_association.public_a,
    aws_route_table_association.public_b,
    aws_security_group.ec2_sg,
    terraform_data.wait_for_k8s
  ]

  metadata {
    name      = "web-html"
    namespace = "default"
  }

  data = {
    "index.html" = <<-EOF
                  <!DOCTYPE html>
                  <html lang="en">
                  <head>
                      <meta charset="UTF-8">
                      <meta name="viewport" content="width=device-width, initial-scale=1.0">
                      <title>DevOps 1-Click K8s on AWS</title>
                      <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap" rel="stylesheet">
                      <style>
                          :root {
                              --bg-color: #0d0e12;
                              --card-bg: rgba(255, 255, 255, 0.03);
                              --border-color: rgba(255, 255, 255, 0.08);
                              --text-primary: #ffffff;
                              --text-secondary: #94a3b8;
                              --accent-primary: #38bdf8;
                              --accent-secondary: #818cf8;
                              --success: #34d399;
                          }
                          * {
                              box-sizing: border-box;
                              margin: 0;
                              padding: 0;
                          }
                          body {
                              font-family: 'Outfit', sans-serif;
                              background-color: var(--bg-color);
                              color: var(--text-primary);
                              min-height: 100vh;
                              display: flex;
                              flex-direction: column;
                              justify-content: center;
                              align-items: center;
                              overflow-x: hidden;
                              background-image: 
                                  radial-gradient(circle at 10% 20%, rgba(56, 189, 248, 0.08) 0%, transparent 40%),
                                  radial-gradient(circle at 90% 80%, rgba(129, 140, 248, 0.08) 0%, transparent 40%);
                          }
                          .container {
                              max-width: 800px;
                              width: 90%;
                              padding: 40px;
                              background: rgba(255, 255, 255, 0.02);
                              backdrop-filter: blur(16px);
                              -webkit-backdrop-filter: blur(16px);
                              border: 1px solid var(--border-color);
                              border-radius: 24px;
                              box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
                              text-align: center;
                              animation: fadeIn 1s ease-out;
                          }
                          @keyframes fadeIn {
                              from { opacity: 0; transform: translateY(20px); }
                              to { opacity: 1; transform: translateY(0); }
                          }
                          h1 {
                              font-size: 2.5rem;
                              font-weight: 800;
                              margin-bottom: 10px;
                              background: linear-gradient(135deg, var(--accent-primary), var(--accent-secondary));
                              -webkit-background-clip: text;
                              -webkit-text-fill-color: transparent;
                          }
                          .subtitle {
                              color: var(--text-secondary);
                              font-size: 1.1rem;
                              margin-bottom: 40px;
                          }
                          .status-badge {
                              display: inline-flex;
                              align-items: center;
                              gap: 8px;
                              padding: 8px 16px;
                              background: rgba(52, 211, 153, 0.1);
                              border: 1px solid rgba(52, 211, 153, 0.2);
                              border-radius: 100px;
                              color: var(--success);
                              font-weight: 600;
                              font-size: 0.9rem;
                              margin-bottom: 30px;
                          }
                          .status-dot {
                              width: 8px;
                              height: 8px;
                              background-color: var(--success);
                              border-radius: 50%;
                              box-shadow: 0 0 10px var(--success);
                              animation: pulse 1.5s infinite;
                          }
                          @keyframes pulse {
                              0% { transform: scale(0.9); opacity: 0.6; }
                              50% { transform: scale(1.2); opacity: 1; }
                              100% { transform: scale(0.9); opacity: 0.6; }
                          }
                          .grid {
                              display: grid;
                              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                              gap: 20px;
                              margin-bottom: 40px;
                          }
                          .card {
                              background: var(--card-bg);
                              border: 1px solid var(--border-color);
                              border-radius: 16px;
                              padding: 24px;
                              transition: all 0.3s ease;
                              position: relative;
                              overflow: hidden;
                          }
                          .card::before {
                              content: '';
                              position: absolute;
                              top: 0;
                              left: 0;
                              width: 100%;
                              height: 100%;
                              background: linear-gradient(135deg, rgba(56, 189, 248, 0.05), rgba(129, 140, 248, 0.05));
                              opacity: 0;
                              transition: opacity 0.3s ease;
                          }
                          .card:hover {
                              transform: translateY(-5px);
                              border-color: rgba(56, 189, 248, 0.3);
                              box-shadow: 0 10px 20px rgba(56, 189, 248, 0.05);
                          }
                          .card:hover::before {
                              opacity: 1;
                          }
                          .card-title {
                              font-size: 0.85rem;
                              text-transform: uppercase;
                              letter-spacing: 0.05em;
                              color: var(--text-secondary);
                              margin-bottom: 8px;
                          }
                          .card-value {
                              font-size: 1.25rem;
                              font-weight: 600;
                              color: var(--text-primary);
                          }
                          .footer {
                              margin-top: 20px;
                              font-size: 0.85rem;
                              color: var(--text-secondary);
                              border-top: 1px solid var(--border-color);
                              padding-top: 20px;
                          }
                          .visualizer {
                              margin: 30px 0;
                              padding: 20px;
                              background: rgba(0,0,0,0.2);
                              border-radius: 16px;
                              border: 1px dashed var(--border-color);
                          }
                          .k8s-cluster {
                              display: flex;
                              justify-content: center;
                              align-items: center;
                              gap: 15px;
                              margin-top: 15px;
                          }
                          .k8s-node {
                              padding: 10px 20px;
                              background: rgba(56, 189, 248, 0.1);
                              border: 1px solid rgba(56, 189, 248, 0.3);
                              border-radius: 10px;
                              font-size: 0.9rem;
                              font-weight: 600;
                          }
                          .k8s-pod {
                              width: 12px;
                              height: 12px;
                              background: var(--success);
                              border-radius: 50%;
                              display: inline-block;
                              margin-left: 5px;
                              animation: bounce 2s infinite ease-in-out;
                          }
                          .k8s-pod:nth-child(2) { animation-delay: 0.3s; }
                          .k8s-pod:nth-child(3) { animation-delay: 0.6s; }
                          @keyframes bounce {
                              0%, 100% { transform: translateY(0); }
                              50% { transform: translateY(-6px); }
                          }
                      </style>
                  </head>
                  <body>
                      <div class="container">
                          <div class="status-badge">
                              <span class="status-dot"></span>
                              System Operational
                          </div>
                          <h1>DevOps 1-Click Kubernetes</h1>
                          <p class="subtitle">Fully automated provisioning from Terraform to AWS & K8s</p>
                          
                          <div class="grid">
                              <div class="card">
                                  <div class="card-title">Cloud Provider</div>
                                  <div class="card-value">AWS</div>
                              </div>
                              <div class="card">
                                  <div class="card-title">Instance Type</div>
                                  <div class="card-value">t3.micro</div>
                              </div>
                              <div class="card">
                                  <div class="card-title">Region</div>
                                  <div class="card-value">us-east-1</div>
                              </div>
                              <div class="card">
                                  <div class="card-title">Kubernetes</div>
                                  <div class="card-value">Kind</div>
                              </div>
                          </div>

                          <div class="visualizer">
                              <h3 style="font-size: 1rem; color: var(--text-secondary);">Cluster Visualizer</h3>
                              <div class="k8s-cluster">
                                  <div class="k8s-node">Control Plane</div>
                                  <div style="color: var(--text-secondary);">➔</div>
                                  <div class="k8s-node">
                                      Active Pods: 
                                      <span class="k8s-pod"></span>
                                      <span class="k8s-pod"></span>
                                      <span class="k8s-pod"></span>
                                  </div>
                              </div>
                          </div>

                          <div class="footer">
                              Managed by Terraform • Built with Nginx & Docker • Vietnamese AWS Accelerator p2
                          </div>
                      </div>
                  </body>
                  </html>
                  EOF
  }
}

# --- Kubernetes Deployment ---
resource "kubernetes_deployment" "web" {
  depends_on = [
    aws_route_table_association.public_a,
    aws_route_table_association.public_b,
    aws_security_group.ec2_sg,
    terraform_data.wait_for_k8s
  ]

  metadata {
    name = "web-deployment"
    labels = {
      app = "web"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "web"
      }
    }

    template {
      metadata {
        labels = {
          app = "web"
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "web"

          resources {
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
          }

          port {
            container_port = 80
          }

          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html-volume"
          config_map {
            name = kubernetes_config_map.web_html.metadata[0].name
          }
        }
      }
    }
  }
}

# --- Kubernetes Service ---
resource "kubernetes_service" "web" {
  depends_on = [
    aws_route_table_association.public_a,
    aws_route_table_association.public_b,
    aws_security_group.ec2_sg,
    terraform_data.wait_for_k8s
  ]

  metadata {
    name = "web-service"
  }

  spec {
    selector = {
      app = "web"
    }

    port {
      port        = 80
      target_port = 80
      node_port   = 30080
    }

    type = "NodePort"
  }
}
