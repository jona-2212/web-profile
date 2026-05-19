# ============================================================
# outputs.tf – Output Values after terraform apply
# ============================================================

# ---- Jenkins Outputs ----

output "jenkins_public_ip" {
  description = "Public IP address of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins server"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}"
}

output "jenkins_get_password" {
  description = "Command to retrieve Jenkins initial admin password"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}

# ---- SonarQube Outputs ----

output "sonarqube_public_ip" {
  description = "Public IP address of SonarQube server"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_url" {
  description = "SonarQube Web UI URL (default credentials: admin/admin)"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}

output "sonarqube_ssh_command" {
  description = "SSH command to connect to SonarQube server"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.sonarqube.public_ip}"
}

# ---- Docker Server Outputs ----

output "docker_public_ip" {
  description = "Public IP address of Docker deployment server"
  value       = aws_instance.docker.public_ip
}

output "docker_app_url" {
  description = "Application URL on Docker server"
  value       = "http://${aws_instance.docker.public_ip}"
}

output "docker_ssh_command" {
  description = "SSH command to connect to Docker server"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.docker.public_ip}"
}

# ---- GitHub Webhook Output ----

output "github_webhook_url" {
  description = "GitHub Webhook URL (automatically configured by Terraform)"
  value       = "http://${aws_instance.jenkins.public_ip}:8080/github-webhook/"
}

# ---- Summary ----

output "summary" {
  description = "Complete summary of all resources created"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║         CI/CD Pipeline – Terraform Deployment Summary        ║
    ╚══════════════════════════════════════════════════════════════╝

    🔧 JENKINS
       IP       : ${aws_instance.jenkins.public_ip}
       Web UI   : http://${aws_instance.jenkins.public_ip}:8080
       SSH      : ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}

    📊 SONARQUBE
       IP       : ${aws_instance.sonarqube.public_ip}
       Web UI   : http://${aws_instance.sonarqube.public_ip}:9000
       SSH      : ssh -i ${var.key_name}.pem ubuntu@${aws_instance.sonarqube.public_ip}
       Login    : admin / admin (ubah setelah login pertama)

    🐳 DOCKER SERVER
       IP       : ${aws_instance.docker.public_ip}
       App URL  : http://${aws_instance.docker.public_ip}
       SSH      : ssh -i ${var.key_name}.pem ubuntu@${aws_instance.docker.public_ip}

    🔗 GITHUB WEBHOOK
       URL      : http://${aws_instance.jenkins.public_ip}:8080/github-webhook/
       Status   : ✅ Otomatis dikonfigurasi oleh Terraform

    ═══════════════════════════════════════════════════════════════
    LANGKAH SELANJUTNYA:
    1. Tunggu 5-10 menit agar semua server selesai inisialisasi
    2. Jalankan: bash post-provision.sh
    3. Ikuti panduan di README.md bagian "Manual Configuration"
    ═══════════════════════════════════════════════════════════════
  EOT
}
