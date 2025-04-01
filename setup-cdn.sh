#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting CDN Server Setup..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate required variables
validate_config() {
    local required_vars=("PROJECT_NAME" "CDN_PORT" "CDN_DOMAIN" "ADMIN_EMAIL" "BACKEND_IP" "BACKEND_PORT")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "❌ Error: The following required variables are not set in config.private:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi

    # Validate port numbers
    if ! [[ "$CDN_PORT" =~ ^[0-9]+$ ]] || [ "$CDN_PORT" -lt 1 ] || [ "$CDN_PORT" -gt 65535 ]; then
        echo "❌ Error: CDN_PORT must be a valid port number (1-65535)"
        exit 1
    fi

    if ! [[ "$BACKEND_PORT" =~ ^[0-9]+$ ]] || [ "$BACKEND_PORT" -lt 1 ] || [ "$BACKEND_PORT" -gt 65535 ]; then
        echo "❌ Error: BACKEND_PORT must be a valid port number (1-65535)"
        exit 1
    fi

    # Validate email format
    if ! [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Error: ADMIN_EMAIL must be a valid email address"
        exit 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Source configuration
if [ ! -f "config.private" ]; then
    echo "❌ Error: config.private not found. Please copy config.template to config.private and edit it."
    exit 1
fi

# Source and validate configuration
echo "📝 Loading configuration..."
source config.private
validate_config

# Set non-interactive frontend and force configuration defaults
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Update system
echo "📦 Updating system..."
apt-get update
apt-get upgrade -y -o Dpkg::Options::="--force-confdef"

# Install Docker and required packages
echo "📦 Installing Docker and required packages..."
apt-get install -y docker.io docker-compose-v2

# Clean up
echo "🧹 Cleaning up..."
apt-get autoremove -y
apt-get clean

# Create project directory
echo "📁 Creating project directory..."
mkdir -p "/opt/${PROJECT_NAME}"
cd "/opt/${PROJECT_NAME}" || exit 1

# Create necessary directories with proper permissions
echo "📁 Setting up required directories..."
mkdir -p nginx/{modules-enabled,sites-available,sites-enabled}
mkdir -p certbot/{conf,www}
mkdir -p /srv/cache
mkdir -p amplify-agent

# Generate UUID for Amplify if not provided
if [ -z "${AMPLIFY_UUID}" ]; then
    AMPLIFY_UUID=$(uuidgen)
    echo "Generated Amplify UUID: ${AMPLIFY_UUID}"
fi

# Set proper permissions
chmod 755 nginx
chmod 755 nginx/modules-enabled
chmod 755 nginx/sites-available
chmod 755 nginx/sites-enabled
chmod 755 certbot
chmod 755 certbot/conf
chmod 755 certbot/www
chmod 755 /srv/cache
chmod 755 amplify-agent

# Verify source directory exists
if [ ! -d "/root/fivem-cdn-docker" ]; then
    echo "❌ Error: Source directory /root/fivem-cdn-docker not found"
    exit 1
fi

# Copy repository files
echo "📁 Copying repository files..."
cp -r /root/fivem-cdn-docker/* .
cp -r /root/fivem-cdn-docker/.* . 2>/dev/null || true

# Copy and source configuration
echo "📁 Setting up configuration..."
cp /root/fivem-cdn-docker/config.private .

# Generate nginx.conf with substituted variables
echo "📁 Generating nginx.conf..."
cat > nginx/nginx.conf << EOF
user www-data;
worker_processes ${WORKER_PROCESSES};
pid /run/nginx.pid;

# Load other modules
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections ${WORKER_CONNECTIONS};
        # multi_accept on;
}

# HTTP configuration
http {
        ##
        # Basic Settings
        ##

        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        # server_tokens off;

        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        ##
        # Logging Settings
        ##
        access_log ${ACCESS_LOG} combined;
        error_log ${ERROR_LOG} warn;

        ##
        # Extended Log Format
        ##
        log_format  main_ext  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" '
                      '"\$host" sn="\$server_name" '
                      'rt=\$request_time '
                      'ua="\$upstream_addr" us="\$upstream_status" '
                      'ut="\$upstream_response_time" ul="\$upstream_response_length" '
                      'cs=\$upstream_cache_status' ;

        ##
        # Gzip Settings
        ##

        gzip on;

        # gzip_vary on;
        # gzip_proxied any;
        # gzip_comp_level 6;
        # gzip_buffers 16 8k;
        # gzip_http_version 1.1;
        # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

        ##
        # Virtual Host Configs
        ##

        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}

# Stream configuration for TCP/UDP proxying
stream {
        upstream backend {
                server ${BACKEND_IP}:${CDN_PORT};
        }
        server {
                listen ${CDN_PORT};
                proxy_pass backend;
        }
        server {
                listen ${CDN_PORT} udp reuseport;
                proxy_pass backend;
        }
}
EOF

# Generate site.conf with substituted variables
echo "📁 Generating site configuration..."
cat > nginx/sites-available/${PROJECT_NAME}.conf << EOF
upstream backend {
    # use the actual server IP here, or if separate, a proxy server
    server ${BACKEND_IP}:${BACKEND_PORT};
}

# assuming this path exists
proxy_cache_path /srv/cache levels=1:2 keys_zone=${PROJECT_NAME}_cache:${CACHE_MEMORY} max_size=${CACHE_MAX_SIZE} inactive=${CACHE_INACTIVE};

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name ${CDN_DOMAIN};

    access_log ${ACCESS_LOG} main_ext;
    error_log ${ERROR_LOG} warn;

    # Health check endpoint
    location /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'healthy\n';
    }

    # NGINX Amplify stub_status
    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }

    # Let's Encrypt certificates
    ssl_certificate /etc/letsencrypt/live/${CDN_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CDN_DOMAIN}/privkey.pem;

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        # required to pass auth headers correctly
        proxy_pass_request_headers on;
        # required to not make deferrals close the connection instantly
        proxy_http_version 1.1;
        proxy_pass http://backend;
    }

    # extra block for a caching proxy
    location /files/ {
        proxy_pass http://backend\$request_uri;
        add_header X-Cache-Status \$upstream_cache_status;
        proxy_cache_lock on;
        proxy_cache ${PROJECT_NAME}_cache;
        proxy_cache_valid ${CACHE_VALIDITY};
        proxy_cache_key \$request_uri\$is_args\$args;
        proxy_cache_revalidate on;
        proxy_cache_min_uses 1;
    }
}
EOF

# Generate temporary default configuration without SSL
echo "📁 Generating default configuration..."
cat > nginx/sites-available/default.conf << EOF
upstream backend {
    server ${BACKEND_IP}:${BACKEND_PORT};
}

# Cache path configuration
proxy_cache_path /srv/cache levels=1:2 keys_zone=${PROJECT_NAME}_cache:${CACHE_MEMORY} max_size=${CACHE_MAX_SIZE} inactive=${CACHE_INACTIVE};

# HTTP server for initial setup (no SSL)
server {
    listen 80;
    listen [::]:80;
    server_name ${CDN_DOMAIN};

    access_log ${ACCESS_LOG} main_ext;
    error_log ${ERROR_LOG} warn;

    # Health check endpoint
    location /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'healthy\n';
    }

    # NGINX Amplify stub_status
    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_pass_request_headers on;
        proxy_http_version 1.1;
        proxy_pass http://backend;
    }

    # extra block for a caching proxy
    location /files/ {
        proxy_pass http://backend\$request_uri;
        add_header X-Cache-Status \$upstream_cache_status;
        proxy_cache_lock on;
        proxy_cache ${PROJECT_NAME}_cache;
        proxy_cache_valid ${CACHE_VALIDITY};
        proxy_cache_key \$request_uri\$is_args\$args;
        proxy_cache_revalidate on;
        proxy_cache_min_uses 1;
    }
}
EOF

# Generate docker-compose.yml
echo "📁 Generating docker-compose.yml..."
cat > docker-compose.yml << EOF
services:
  ${PROJECT_NAME}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}
    restart: unless-stopped
    ports:
      - "${CDN_PORT}:${CDN_PORT}"
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/sites-available:/etc/nginx/sites-available
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
      - /srv/cache:/srv/cache
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - CDN_PORT=${CDN_PORT}
      - CDN_DOMAIN=${CDN_DOMAIN}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
      - API_KEY=${AMPLIFY_API_KEY}
      - AMPLIFY_UUID=${AMPLIFY_UUID}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - ${PROJECT_NAME}_network

networks:
  ${PROJECT_NAME}_network:
    driver: bridge
EOF

# Create init script to setup SSL automatically
echo "📁 Creating SSL initialization script..."
cat > init-ssl.sh << EOF
#!/bin/bash

# Check if container is running
if ! docker compose ps | grep -q "${PROJECT_NAME}" || ! docker compose ps | grep -q "running"; then
  echo "Container not running. Starting container..."
  docker compose up -d
  sleep 5
fi

echo "Obtaining SSL certificate..."

# Check if staging environment is enabled
if [ "${LETS_ENCRYPT_STAGING}" = "true" ]; then
    echo "Using Let's Encrypt staging environment..."
    docker compose exec ${PROJECT_NAME} certbot --nginx -d ${CDN_DOMAIN} --non-interactive --agree-tos --email ${ADMIN_EMAIL} --staging
else
    echo "Using Let's Encrypt production environment..."
    docker compose exec ${PROJECT_NAME} certbot --nginx -d ${CDN_DOMAIN} --non-interactive --agree-tos --email ${ADMIN_EMAIL}
fi

# Check if certificate was created successfully
if [ \$? -eq 0 ]; then
    echo "Certificate obtained successfully!"
else
    echo "Failed to obtain certificate. This might be due to rate limiting."
    echo "Please check the error message above and try one of these options:"
    echo "1. Set LETS_ENCRYPT_STAGING=true in config.private to use staging environment"
    echo "2. Wait for the rate limit to reset"
    echo "3. Use existing certificates by copying them to ./certbot/conf/live/${CDN_DOMAIN}/"
    echo "4. Try again later"
    exit 1
fi

# Restart container completely to ensure clean state
echo "Restarting container to apply SSL configuration..."
docker compose down
sleep 2
docker compose up -d
sleep 5

# Verify configuration
echo "Verifying SSL setup..."
docker compose exec ${PROJECT_NAME} nginx -t

echo "SSL setup complete! Your CDN is now accessible at https://${CDN_DOMAIN}"
echo "To verify installation: curl -I https://${CDN_DOMAIN}"
EOF
chmod +x init-ssl.sh

# Verify critical files exist
for file in "Dockerfile" "nginx/nginx.conf" "nginx/sites-available/${PROJECT_NAME}.conf" "nginx/sites-available/default.conf" "docker-compose.yml" "init-ssl.sh"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Required file $file not found"
        exit 1
    fi
done

# Verify directories exist
for dir in "nginx" "certbot" "amplify-agent"; do
    if [ ! -d "$dir" ]; then
        echo "❌ Error: Required directory $dir not found"
        exit 1
    fi
done

# Configure firewall
echo "🛡️ Configuring firewall..."
if command_exists ufw; then
    ufw allow 443/tcp
    ufw allow "${CDN_PORT}/tcp"
    ufw allow "${CDN_PORT}/udp"
fi

echo "✅ Setup completed successfully!"
echo "📝 After reboot, run:"
echo "(cd /opt/${PROJECT_NAME} && docker compose up -d && ./init-ssl.sh)"

while true; do
    read -p "Would you like to restart now? (Y/N): " yn
    case $yn in
        [Yy]* ) echo "Rebooting in 5 seconds..."; sleep 5; reboot; break;;
        [Nn]* ) echo "Setup complete. Please restart manually when ready."; exit 0;;
        * ) echo "Please answer Y or N.";;
    esac
done 