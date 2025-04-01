FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install nginx, certbot, and cron
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y nginx libnginx-mod-stream certbot python3-certbot-nginx cron curl gnupg2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Ensure Nginx directories exist
RUN mkdir -p /etc/nginx/sites-enabled /etc/nginx/conf.d /srv/cache && \
    chmod -R 755 /srv/cache

# We'll mount the config files at runtime instead of copying them here
# Remove default site
RUN rm -f /etc/nginx/sites-enabled/default

# Setup Certbot auto-renewal
RUN echo "0 */12 * * * certbot renew --quiet --deploy-hook 'nginx -s reload'" > /etc/cron.d/certbot-renew && \
    chmod 0644 /etc/cron.d/certbot-renew

# Create entrypoint script with SSL certificate check and Amplify agent
RUN echo '#!/bin/bash\n\
\n\
setup_nginx() {\n\
  if [ -z "$PROJECT_NAME" ]; then\n\
    echo "Error: PROJECT_NAME is not set! Using default site.conf"\n\
    PROJECT_NAME_CONF="site.conf"\n\
  else\n\
    PROJECT_NAME_CONF="${PROJECT_NAME}.conf"\n\
  fi\n\
\n\
  # Clean up sites-enabled\n\
  rm -f /etc/nginx/sites-enabled/*\n\
\n\
  # Check if SSL certificates exist\n\
  if [ -z "$CDN_DOMAIN" ]; then\n\
    echo "Warning: CDN_DOMAIN is not set!"\n\
    CERT_PATH="/etc/letsencrypt/live/example.com/fullchain.pem"\n\
  else\n\
    CERT_PATH="/etc/letsencrypt/live/$CDN_DOMAIN/fullchain.pem"\n\
  fi\n\
\n\
  if [ -f "$CERT_PATH" ]; then\n\
    echo "SSL certificates found, using $PROJECT_NAME_CONF"\n\
    ln -sf /etc/nginx/sites-available/$PROJECT_NAME_CONF /etc/nginx/sites-enabled/\n\
  else\n\
    echo "SSL certificates not found, using default.conf"\n\
    ln -sf /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/\n\
  fi\n\
}\n\
\n\
# Set up Nginx configuration\n\
setup_nginx\n\
\n\
# Start cron service for certificate renewal\n\
service cron start\n\
\n\
# Install and configure Amplify agent if API key is provided\n\
if [ ! -z "$API_KEY" ]; then\n\
  echo "Installing NGINX Amplify agent..."\n\
  curl -sS -L -O https://github.com/nginxinc/nginx-amplify-agent/raw/master/packages/install.sh && \
  chmod +x ./install.sh && \
  DEBIAN_FRONTEND=noninteractive API_KEY="$API_KEY" ./install.sh -y && \
  rm -f install.sh\n\
  \n\
  # Verify agent is running\n\
  if pgrep -f "amplify-agent" > /dev/null; then\n\
    echo "NGINX Amplify agent is running"\n\
  else\n\
    echo "Failed to start NGINX Amplify agent"\n\
    exit 1\n\
  fi\n\
fi\n\
\n\
# Check for certificates periodically in the background\n\
(while true; do\n\
  sleep 30\n\
  if [ -z "$CDN_DOMAIN" ]; then\n\
    CERT_PATH="/etc/letsencrypt/live/example.com/fullchain.pem"\n\
  else\n\
    CERT_PATH="/etc/letsencrypt/live/$CDN_DOMAIN/fullchain.pem"\n\
  fi\n\
\n\
  # If we previously used default.conf and now certificates exist\n\
  if [ -L "/etc/nginx/sites-enabled/default.conf" ] && [ -f "$CERT_PATH" ]; then\n\
    echo "Certificates have been installed. Reconfiguring Nginx..."\n\
    setup_nginx\n\
    nginx -s reload\n\
    echo "Nginx reconfigured to use SSL."\n\
  fi\n\
done) &\n\
\n\
# Start Nginx in foreground\n\
echo "Starting Nginx..."\n\
nginx -g "daemon off;"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Expose ports (will be overridden by docker-compose)
EXPOSE 80 443

# Start Nginx with our entrypoint script
CMD ["/entrypoint.sh"] 