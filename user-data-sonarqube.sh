#!/bin/bash
# ============================================================
# user-data-sonarqube.sh
# SonarQube Server Bootstrap Script
# Dijalankan otomatis saat EC2 pertama kali start
# ============================================================
set -e
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "  SonarQube Server Setup – $(date)"
echo "=========================================="

# ---- Update & Install Prerequisites ----
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

apt-get install -y \
  curl \
  wget \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release

# ---- System Configuration (REQUIRED for SonarQube) ----
echo "[INFO] Configuring system limits for SonarQube..."

# Increase virtual memory maps – SonarQube (Elasticsearch) requires this
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072

# Persist across reboots
cat >> /etc/sysctl.conf << 'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF

# Increase open file limits for sonarqube user
cat >> /etc/security/limits.conf << 'EOF'
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
ubuntu      -   nofile   131072
EOF

# ---- Install Java 17 ----
echo "[INFO] Installing Java 17..."
apt-get install -y openjdk-17-jdk
echo "[INFO] Java: $(java -version 2>&1 | head -1)"

# ---- Install PostgreSQL (SonarQube database backend) ----
echo "[INFO] Installing PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

systemctl enable postgresql
systemctl start postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Create SonarQube database user and database
echo "[INFO] Creating SonarQube database..."
sudo -u postgres psql << 'SQL'
CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar@Secure123';
CREATE DATABASE sonardb OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonardb TO sonar;
SQL

echo "[INFO] PostgreSQL configured for SonarQube."

# ---- Download SonarQube ----
echo "[INFO] Downloading SonarQube 10.4 LTS..."
SONAR_VERSION="10.4.1.88267"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"

wget -q "${SONAR_URL}" -O /tmp/sonarqube.zip

echo "[INFO] Extracting SonarQube..."
unzip -q /tmp/sonarqube.zip -d /opt/
mv /opt/sonarqube-${SONAR_VERSION} /opt/sonarqube
rm /tmp/sonarqube.zip

# ---- Create SonarQube User ----
useradd -r -m -s /bin/bash sonarqube || echo "[WARN] User sonarqube may already exist"
chown -R sonarqube:sonarqube /opt/sonarqube

# ---- Configure SonarQube ----
echo "[INFO] Configuring SonarQube..."
cat > /opt/sonarqube/conf/sonar.properties << 'EOF'
# --- Database Configuration ---
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar@Secure123
sonar.jdbc.url=jdbc:postgresql://localhost/sonardb

# --- Web Server ---
sonar.web.host=0.0.0.0
sonar.web.port=9000

# --- Paths ---
sonar.path.data=/opt/sonarqube/data
sonar.path.temp=/opt/sonarqube/temp

# --- Elasticsearch (embedded) ---
sonar.search.javaAdditionalOpts=-Dnode.store.allow_mmap=false

# --- Logging ---
sonar.log.level=INFO
EOF

chown sonarqube:sonarqube /opt/sonarqube/conf/sonar.properties

# ---- Create Systemd Service ----
echo "[INFO] Creating SonarQube systemd service..."
cat > /etc/systemd/system/sonarqube.service << 'EOF'
[Unit]
Description=SonarQube Code Quality Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=on-failure
RestartSec=30
TimeoutStartSec=300

LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "[INFO] SonarQube service started. Waiting for it to be ready (may take 3-5 minutes)..."

# ---- Write Info File ----
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "UNKNOWN")

cat > /home/ubuntu/sonarqube-info.txt << EOF
==========================================
  SonarQube Server – Setup Complete
  $(date)
==========================================
Public IP     : ${PUBLIC_IP}
SonarQube URL : http://${PUBLIC_IP}:9000
Default Login : admin / admin
              (Kamu WAJIB ganti password setelah login pertama!)

DB Host       : localhost
DB Name       : sonardb
DB User       : sonar
DB Password   : sonar@Secure123

Log File      : /var/log/user-data.log
SonarQube Log : /opt/sonarqube/logs/sonar.log

Note: SonarQube butuh 3-5 menit untuk fully start.
      Cek log: sudo -u sonarqube tail -f /opt/sonarqube/logs/web.log
==========================================
EOF

chmod 600 /home/ubuntu/sonarqube-info.txt
chown ubuntu:ubuntu /home/ubuntu/sonarqube-info.txt

echo "=========================================="
echo "  SonarQube Setup Complete – $(date)"
echo "  URL: http://${PUBLIC_IP}:9000"
echo "  Default: admin / admin"
echo "  NOTE: Tunggu 3-5 menit sebelum akses UI"
echo "=========================================="
