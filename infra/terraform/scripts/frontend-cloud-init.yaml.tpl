#cloud-config
package_update: true
packages:
  - nginx
  - unzip

write_files:
  - path: /etc/nginx/sites-available/todoapp
    content: |
      server {
          listen 80 default_server;
          server_name _;

          root /var/www/todoapp;
          index index.html;

          location /health {
              default_type text/plain;
              return 200 'ok';
          }

          location /api/ {
              proxy_pass http://${backend_lb_ip}:8000/api/;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }

          location / {
              try_files $uri /index.html;
          }
      }

  - path: /opt/deploy/deploy-frontend.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      DEST=/var/www/todoapp
      mkdir -p "$DEST"
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT

      azcopy login --identity >/tmp/azcopy-login.log 2>&1
      azcopy copy "https://${storage_account_name}.blob.core.windows.net/frontend-releases/latest.zip" "$TMP/latest.zip" --output-type text
      unzip -o "$TMP/latest.zip" -d "$DEST"
      systemctl reload nginx
      echo "$(date -u +%FT%TZ) deployed frontend" >> /var/log/todoapp-deploy.log

runcmd:
  - rm -f /etc/nginx/sites-enabled/default
  - ln -sf /etc/nginx/sites-available/todoapp /etc/nginx/sites-enabled/todoapp
  - systemctl enable nginx
  - systemctl restart nginx
  - curl -sL https://aka.ms/downloadazcopy-v10-linux -o /tmp/azcopy.tar.gz
  - mkdir -p /tmp/azcopy_extract
  - tar -xzf /tmp/azcopy.tar.gz -C /tmp/azcopy_extract --strip-components=1
  - cp /tmp/azcopy_extract/azcopy /usr/local/bin/azcopy
  - chmod +x /usr/local/bin/azcopy
  - mkdir -p /var/www/todoapp
  - echo "<!doctype html><title>todoapp</title><p>Waiting for first release...</p>" > /var/www/todoapp/index.html
  - /opt/deploy/deploy-frontend.sh || echo "initial deploy skipped - no release artifact published yet"
