#!/bin/bash
# ============================================================
# user-data-jenkins.sh
# Jenkins Server Bootstrap Script
# Dijalankan otomatis saat EC2 pertama kali start
# ============================================================
set -e
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "  Jenkins Server Setup – $(date)"
echo "=========================================="

# ---- Update & Install Prerequisites ----
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

apt-get install -y \
  curl \
  wget \
  git \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  fontconfig

# ---- Install Java 21 (Required for Jenkins 2.426+ / LTS 2025) ----
# Jenkins 2.463+ requires Java 21 minimum. Java 17 is no longer supported.
echo "[INFO] Installing Java 21..."
apt-get install -y openjdk-21-jdk
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
echo "[INFO] Java version: $(java -version 2>&1 | head -1)"

# ---- Install Jenkins ----
echo "[INFO] Adding Jenkins repository..."
# NOTE: Jenkins key expired 2026-03-26. Use trusted=yes until Jenkins renews it.
echo "deb [trusted=yes] https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y --allow-unauthenticated jenkins

echo "[INFO] Enabling Jenkins service..."
systemctl enable jenkins

# ---- Install Plugins BEFORE starting Jenkins (offline method) ----
# Menggunakan jenkins-plugin-manager untuk install plugin sebelum Jenkins start
# Ini lebih reliable daripada install via CLI setelah Jenkins start

echo "[INFO] Downloading Jenkins Plugin Manager..."
PLUGIN_MGR_VERSION="2.12.15"
wget -q \
  "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PLUGIN_MGR_VERSION}/jenkins-plugin-manager-${PLUGIN_MGR_VERSION}.jar" \
  -O /opt/jenkins-plugin-manager.jar

# Pastikan direktori plugins ada
mkdir -p /var/lib/jenkins/plugins

echo "[INFO] Creating plugins list..."
cat > /tmp/jenkins-plugins.txt << 'PLUGINS'
sonar
sonar-quality-gates
publish-over-ssh
ssh-steps
git
github
github-branch-source
workflow-aggregator
pipeline-utility-steps
credentials
credentials-binding
ssh-credentials
plain-credentials
matrix-auth
build-timeout
timestamper
ws-cleanup
antisamy-markup-formatter
PLUGINS

echo "[INFO] Installing Jenkins plugins (this may take 3-5 minutes)..."
java -jar /opt/jenkins-plugin-manager.jar \
  --war /usr/share/jenkins/jenkins.war \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --plugin-file /tmp/jenkins-plugins.txt \
  --latest true \
  --verbose || echo "[WARN] Some plugins may have failed – Jenkins will retry on startup"

# Fix ownership after plugin install
chown -R jenkins:jenkins /var/lib/jenkins/plugins/

# ---- Start Jenkins ----
echo "[INFO] Starting Jenkins..."
systemctl start jenkins

# ---- Wait for Jenkins to be fully ready ----
echo "[INFO] Waiting for Jenkins to initialize (may take 2-3 minutes)..."
JENKINS_PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

# Wait for initial admin password to be generated
COUNTER=0
while [ ! -f "${JENKINS_PASS_FILE}" ] && [ $COUNTER -lt 60 ]; do
  sleep 5
  COUNTER=$((COUNTER + 1))
  echo "[INFO] Waiting for initialAdminPassword... (${COUNTER}/60)"
done

if [ -f "${JENKINS_PASS_FILE}" ]; then
  JENKINS_PASS=$(cat "${JENKINS_PASS_FILE}")
  echo "[INFO] Jenkins initial password generated: ${JENKINS_PASS}"
else
  echo "[WARN] initialAdminPassword not found after timeout"
  JENKINS_PASS="CHECK_MANUALLY"
fi

# ---- Install Docker (so Jenkins can build Docker images locally if needed) ----
echo "[INFO] Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker jenkins
usermod -aG docker ubuntu

systemctl enable docker
systemctl start docker

# ---- Write Info File ----
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "UNKNOWN")

cat > /home/ubuntu/jenkins-info.txt << EOF
==========================================
  Jenkins Server – Setup Complete
  $(date)
==========================================
Public IP    : ${PUBLIC_IP}
Jenkins URL  : http://${PUBLIC_IP}:8080
Initial Pass : ${JENKINS_PASS}
Log File     : /var/log/user-data.log
------------------------------------------
Get password:
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
==========================================
EOF

chmod 600 /home/ubuntu/jenkins-info.txt
chown ubuntu:ubuntu /home/ubuntu/jenkins-info.txt

echo "=========================================="
echo "  Jenkins Setup Complete – $(date)"
echo "  Initial Password: ${JENKINS_PASS}"
echo "  URL: http://${PUBLIC_IP}:8080"
echo "=========================================="
