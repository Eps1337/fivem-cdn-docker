# FiveM CDN Docker

A high-performance CDN server for FiveM servers, built with Nginx and Docker. Perfect for serving FiveM resources, assets, and files with blazing-fast speeds and efficient caching.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [FiveM Server Configuration](#fivem-server-configuration)
- [Configuration Options](#configuration-options)
- [Security Features](#security-features)
- [Monitoring](#monitoring)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Features

* 🚀 High-performance Nginx server
* 📈 Nginx Amplify integration 
* 🔒 SSL/TLS encryption with Let's Encrypt
* 💾 Efficient caching system
* 📊 Detailed access and error logging
* 🔄 Automatic cache invalidation
* 🐳 Docker containerization
* ⚡ Optimized for FiveM resource delivery
* ✅ Robust setup validation
* 🔍 Comprehensive error checking
* 🛡️ Automatic directory structure setup

## Prerequisites

### VPS Requirements
* Ubuntu 24.04 LTS x64 (Host OS)
* Docker container: Ubuntu 24.04 LTS (Base image)
* Root access
* Open ports: 80 (HTTP - required for Let's Encrypt), 443 (HTTPS), 30120 (TCP/UDP)
* A domain name pointing to your server

### Recommended Specifications (50+ Players)
* CPU: 2 vCPUs
* RAM: 2GB (2048MB)
* Storage: 65GB SSD
* Bandwidth: 1Gbps+ - 3,000GB/month
* Location: Pick a location geographically close to your desired playerbase to ensure latency below 100ms

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/Eps1337/fivem-cdn-docker.git
cd fivem-cdn-docker
```

2. Copy and edit the configuration:
```bash
cp config.template config.private && nano config.private
```

3. Run the setup script:
```bash
chmod +x setup-cdn.sh && sudo ./setup-cdn.sh
```

4. After rebooting, run this single command to complete the setup:
```bash
(cd /opt/${PROJECT_NAME} && docker compose up -d && ./init-ssl.sh)
```

5. Your CDN is now ready! Visit https://your-cdn-domain to verify it's working.

6. [Configure your FiveM server](#fivem-server-configuration) in TxAdmin.

## Detailed Setup Guide

### 1. Initial Setup

1. SSH into your VPS:
```bash
ssh root@your-vps-ip
```

2. Clone the repository:
```bash
git clone https://github.com/Eps1337/fivem-cdn-docker.git
cd fivem-cdn-docker
```

### 2. Configuration

1. Copy the template configuration:
```bash
cp config.template config.private
```

2. Edit your private configuration:
```bash
nano config.private
```

3. Update the following settings:
```bash
# CDN Configuration Template
# Copy this file to config.private and update the values

# Project configuration
PROJECT_NAME=fivem-cdn

# Backend server configuration
BACKEND_IP=example.com # This is your FiveM server
BACKEND_PORT=30120 # This is your FiveM Game Port (Typically 30120)

# CDN Configuration
CDN_DOMAIN=cdn.example.com # xyz.example.com
CDN_PORT=30120 # This is your FiveM Game Port (Typically 30120)

# Cache configuration
CACHE_MEMORY=48m
CACHE_MAX_SIZE=35g
CACHE_INACTIVE=14d
CACHE_VALIDITY=1y

# Let's Encrypt configuration
ADMIN_EMAIL=admin@example.com
LETS_ENCRYPT_STAGING=true  # Set to true to use staging environment for testing 

# Logging configuration
ACCESS_LOG=/var/log/nginx/${PROJECT_NAME}.access.log
ERROR_LOG=/var/log/nginx/${PROJECT_NAME}.error.log

# Nginx configuration
WORKER_CONNECTIONS=768
WORKER_PROCESSES=auto 

# NGINX Amplify configuration (optional - comment the line out with # to skip)
# https://amplify.nginx.com/
AMPLIFY_API_KEY=your_api_key_here
AMPLIFY_UUID=${PROJECT_NAME}  # Optional: Will be auto-generated if not provided
```

### 3. Start the CDN

1. Make the setup script executable:
```bash
chmod +x setup-cdn.sh
```

2. Run the setup script:
```bash
sudo ./setup-cdn.sh
```

3. After the system reboots, navigate to the installation directory:
```bash
cd /opt/${PROJECT_NAME}
```

4. Start the Docker container:
```bash
docker compose up -d
```

5. Set up SSL certificates:
```bash
./init-ssl.sh
```

6. After the SSL setup completes, your CDN will be available at:
```
https://${CDN_DOMAIN}
```

## FiveM Server Configuration

Once your CDN is set up and running, you'll need to configure your FiveM server to use it. This configuration enables resource caching and optional game traffic tunneling through your CDN.

For detailed information about FiveM proxy setup, refer to the [official FiveM documentation](https://docs.fivem.net/docs/server-manual/proxy-setup/).

### 1. Access TxAdmin
1. Open your TxAdmin panel
2. Navigate to your server configuration
3. Find the section where you can add custom configuration

### 2. Add CDN Configuration
Add the following configuration to your server.cfg:

```cfg
# ==============================================
# CDN Configuration
# ==============================================

# Resource Caching Configuration
# This enables caching of all server resources through the CDN
set adhesive_cdnKey "your_secure_password_here"
fileserver_add ".*" "https://your-cdn-domain.com/files"

# Game Traffic Configuration
# Choose ONE of the following options:

# Option 1: Direct Traffic
# Players connect directly to your server
set sv_endpoints "your_server_ip:30120"

# Option 2: CDN Tunneling
# Routes traffic through the CDN for enhanced security and DDoS protection
# Note: May add slight latency due to additional routing
#set sv_endpoints "your-cdn-domain.com:30120"
```

### 3. Configuration Details

#### Resource Caching
- `adhesive_cdnKey`: A secure password to authenticate with the CDN
- `fileserver_add`: Enables caching for all server resources
  - `".*"`: Matches all resource files
  - `"https://your-cdn-domain.com/files"`: Your CDN's file server URL

#### Game Traffic Options
1. **Direct Traffic**
   - Players connect directly to your server
   - Lower latency for players near your server
   - More server bandwidth usage
   - Use: `set sv_endpoints "your_server_ip:30120"`

2. **CDN Tunneling**
   - Routes all traffic through the CDN
   - Provides DDoS protection for your main server
   - Hides your server's real IP address
   - May add slight latency due to additional routing
   - Use: `set sv_endpoints "your-cdn-domain.com:30120"`

### 4. Important Notes
- Replace `your-cdn-domain.com` with your actual CDN domain
- Replace `your_secure_password_here` with a strong password
- Replace `your_server_ip` with your server's public IP address
- Make sure your CDN domain is properly configured in DNS
- Choose the traffic option that best suits your needs based on your server's requirements
- To disable the CDN temporarily or remove it, simply comment out the resource caching lines:
  ```cfg
  #set adhesive_cdnKey "your_secure_password_here"
  #fileserver_add ".*" "https://your-cdn-domain.com/files"
  ```
- After making any changes to the CDN configuration, you must restart your FiveM server for the changes to take effect

## Configuration Options

The CDN is configured through the `config.private` file (not included in repository for security):

### Project Settings
* `PROJECT_NAME`: Name of your project (e.g., fivem-cdn)

### Backend Server
* `BACKEND_IP`: Your FiveM server IP
* `BACKEND_PORT`: Your FiveM server port (default: 30120)

### CDN Configuration
* `CDN_DOMAIN`: Your CDN domain
* `CDN_PORT`: Port for CDN server connections (default: 30120)

### Cache Settings
* `CACHE_MEMORY`: Memory allocated for cache (e.g., 48m)
* `CACHE_MAX_SIZE`: Maximum cache size (e.g., 35g)
* `CACHE_INACTIVE`: Cache invalidation time (e.g., 14d)
* `CACHE_VALIDITY`: Cache validity period (e.g., 1y)

For detailed information about Nginx content caching, refer to the [official Nginx documentation](https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/).

### Let's Encrypt Configuration
* `ADMIN_EMAIL`: Email address for Let's Encrypt notifications

> **Note:** The CDN automatically handles Let's Encrypt certificate issuance and renewal. Port 80 must remain open for certificate validation and renewal.

### Logging
* `ACCESS_LOG`: Access log file path (uses ${PROJECT_NAME})
* `ERROR_LOG`: Error log file path (uses ${PROJECT_NAME})

### Nginx Settings
* `WORKER_CONNECTIONS`: Number of worker connections
* `WORKER_PROCESSES`: Number of worker processes

## Security Features

* 🔒 SSL/TLS encryption with Let's Encrypt
* 🛡️ Private configuration system
* 🚫 No sensitive data in repository
* 🔐 Restricted file permissions
* 🛡️ Automatic firewall configuration
* 🔄 Automated SSL certificate setup with zero downtime
* 🔒 Graceful fallback to HTTP during initial setup
* ✅ Configuration validation
* 🔍 Comprehensive error checking
* 🛡️ Proper directory permissions

## Monitoring

### View Logs
```bash
# Access logs
docker compose logs -f ${PROJECT_NAME}

# Nginx access logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/nginx/${PROJECT_NAME}.access.log

# Nginx error logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/nginx/${PROJECT_NAME}.error.log

# Amplify agent logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/amplify-agent/agent.log
```

### Check Status
```bash
# Docker container status
docker compose ps

# Nginx status
docker compose exec ${PROJECT_NAME} nginx -t
```

## Maintenance

### Cache Management

#### Check Cache Size
```bash
# View cache directory size (from host)
du -sh /srv/cache

# View cache directory size (from container)
docker compose exec ${PROJECT_NAME} du -sh /srv/cache

# View detailed cache statistics from Nginx
docker compose exec ${PROJECT_NAME} nginx -T | grep "proxy_cache_path"
```

#### Purge Cache
```bash
# Remove all cached files (from host)
rm -rf /srv/cache/*

# Remove all cached files (from container)
docker compose exec ${PROJECT_NAME} rm -rf /srv/cache/*

# Remove specific cached files (e.g., all .zip files)
find /srv/cache -type f -name "*.zip" -delete

# Restart Nginx to clear memory cache
docker compose restart ${PROJECT_NAME}
```

### Certificate Management

#### Check Certificate Status
```bash
# View certificate expiration
docker compose exec ${PROJECT_NAME} certbot certificates

# Force certificate renewal
docker compose exec ${PROJECT_NAME} certbot renew --force-renewal
```

#### Monitor Certificate Renewal
```bash
# Check certificate renewal logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/letsencrypt/letsencrypt.log

# Check cron job for renewal
docker compose exec ${PROJECT_NAME} cat /etc/cron.d/certbot-renew

# View certificate details including expiration
docker compose exec ${PROJECT_NAME} openssl x509 -in /etc/letsencrypt/live/${CDN_DOMAIN}/cert.pem -noout -dates

# Check Nginx SSL configuration
docker compose exec ${PROJECT_NAME} nginx -T | grep ssl_certificate
```

#### Backup and Restore

##### Create Backups
```bash
# Create backup directory on host
mkdir -p /opt/${PROJECT_NAME}/backups

# Backup Nginx configuration (from container to host)
docker compose exec ${PROJECT_NAME} tar -czf /tmp/nginx-config.tar.gz /etc/nginx/
docker compose cp ${PROJECT_NAME}:/tmp/nginx-config.tar.gz /opt/${PROJECT_NAME}/backups/
docker compose exec ${PROJECT_NAME} rm /tmp/nginx-config.tar.gz

# Backup SSL certificates (from container to host)
docker compose exec ${PROJECT_NAME} tar -czf /tmp/ssl-certificates.tar.gz /etc/letsencrypt/
docker compose cp ${PROJECT_NAME}:/tmp/ssl-certificates.tar.gz /opt/${PROJECT_NAME}/backups/
docker compose exec ${PROJECT_NAME} rm /tmp/ssl-certificates.tar.gz

# Backup all configuration (from container to host)
docker compose exec ${PROJECT_NAME} tar -czf /tmp/cdn-config.tar.gz /etc/nginx/ /etc/letsencrypt/ /etc/amplify-agent/
docker compose cp ${PROJECT_NAME}:/tmp/cdn-config.tar.gz /opt/${PROJECT_NAME}/backups/
docker compose exec ${PROJECT_NAME} rm /tmp/cdn-config.tar.gz
```

##### Restore from Backup
```bash
# Restore Nginx configuration
docker compose cp /opt/${PROJECT_NAME}/backups/nginx-config.tar.gz ${PROJECT_NAME}:/tmp/
docker compose exec ${PROJECT_NAME} tar -xzf /tmp/nginx-config.tar.gz -C /etc/nginx/
docker compose exec ${PROJECT_NAME} rm /tmp/nginx-config.tar.gz

# Restore SSL certificates
docker compose cp /opt/${PROJECT_NAME}/backups/ssl-certificates.tar.gz ${PROJECT_NAME}:/tmp/
docker compose exec ${PROJECT_NAME} tar -xzf /tmp/ssl-certificates.tar.gz -C /etc/letsencrypt/
docker compose exec ${PROJECT_NAME} rm /tmp/ssl-certificates.tar.gz

# Restore all configuration
docker compose cp /opt/${PROJECT_NAME}/backups/cdn-config.tar.gz ${PROJECT_NAME}:/tmp/
docker compose exec ${PROJECT_NAME} tar -xzf /tmp/cdn-config.tar.gz -C /
docker compose exec ${PROJECT_NAME} rm /tmp/cdn-config.tar.gz

# Restart services after restore
docker compose restart ${PROJECT_NAME}
```

> **Note:** Backups are stored in `/opt/${PROJECT_NAME}/backups/` on the host system. Make sure to regularly copy these backups to a secure off-site location.

## Troubleshooting

### Common Issues

#### 1. SSL Certificate Issues
```bash
# Check certificate status
docker compose exec ${PROJECT_NAME} certbot certificates

# View Nginx SSL configuration
docker compose exec ${PROJECT_NAME} nginx -T | grep ssl

# Check SSL logs
tail -f /var/log/nginx/${PROJECT_NAME}.error.log
```

#### 2. Cache Issues
```bash
# Check cache permissions
ls -la /srv/cache

# Verify cache configuration
docker compose exec ${PROJECT_NAME} nginx -T | grep "proxy_cache"

# Check cache access logs
grep "cache" /var/log/nginx/${PROJECT_NAME}.access.log
```

#### 3. Performance Issues
```bash
# Check Nginx worker processes
docker compose exec ${PROJECT_NAME} ps aux | grep nginx

# Monitor Nginx status
docker compose exec ${PROJECT_NAME} nginx -V

# Check system resources
docker stats ${PROJECT_NAME}
```

### Debugging Tools

#### 1. Nginx Debug
```bash
# Test Nginx configuration
docker compose exec ${PROJECT_NAME} nginx -t

# View Nginx configuration
docker compose exec ${PROJECT_NAME} nginx -T

# Check Nginx error logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/nginx/error.log
```

#### 2. Network Debug
```bash
# Check open ports
docker compose exec ${PROJECT_NAME} netstat -tulpn

# Test backend connectivity
docker compose exec ${PROJECT_NAME} curl -v http://${BACKEND_IP}:${BACKEND_PORT}

# Check SSL connection
docker compose exec ${PROJECT_NAME} openssl s_client -connect ${CDN_DOMAIN}:443
```

### Recovery Procedures

#### 1. Container Recovery
```bash
# Stop and remove container
docker compose down

# Clean up volumes (if needed)
docker compose down -v

# Rebuild and start
docker compose up -d --build
```

#### 2. Configuration Recovery
```bash
# Restore from backup
tar -xzf cdn-backup.tar.gz

# Restart services
docker compose restart ${PROJECT_NAME}
```

#### 3. Emergency Mode
```bash
# Stop all services
docker compose down

# Start in HTTP-only mode
docker compose up -d --no-ssl

# Restore SSL after fixing issues
./init-ssl.sh
```

### Monitoring Tools

#### 1. NGINX Amplify
```bash
# Check Amplify agent status
docker compose exec ${PROJECT_NAME} service amplify-agent status

# View Amplify logs
docker compose exec ${PROJECT_NAME} tail -f /var/log/amplify-agent/agent.log

# Restart Amplify agent
docker compose exec ${PROJECT_NAME} service amplify-agent restart
```

#### 2. System Monitoring
```bash
# Monitor container resources
docker stats ${PROJECT_NAME}

# Check system logs
journalctl -u docker

# Monitor network traffic
docker compose exec ${PROJECT_NAME} iftop
```

## Support

For issues and support:
1. Check the [GitHub Issues](https://github.com/Eps1337/fivem-cdn-docker/issues)
2. Review the [NGINX Documentation](https://nginx.org/en/docs/)
3. Check the [Docker Documentation](https://docs.docker.com/)
4. Review the [FiveM Documentation](https://docs.fivem.net/docs/server-manual/proxy-setup/)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

This means you are free to:
* Use this software for any purpose
* Modify the source code
* Distribute the software
* Use it commercially

Under the condition that you:
* Include the original copyright notice
* Include the license text
* State significant changes made to the code
* Make the source code available when distributing
* Include the same license for derivative works