#cloud-config
package_update: true
packages:
  - python3-venv
  - python3-pip
  - unzip
  - cifs-utils

write_files:
  - path: /etc/systemd/system/todo-backend.service
    content: |
      [Unit]
      Description=Todo FastAPI backend
      After=network-online.target mnt-tododata.mount
      Wants=network-online.target

      [Service]
      Type=simple
      WorkingDirectory=/opt/app
      Environment=TODO_DATA_FILE=/mnt/tododata/todos.json
      Environment=ALLOWED_ORIGINS=${allowed_origins}
      ExecStart=/opt/app/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target

  - path: /etc/smbcredentials/tododata.cred
    permissions: '0600'
    content: |
      username=${storage_account_name}
      password=${storage_account_key}

  - path: /opt/deploy/deploy-backend.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      DEST=/opt/app
      mkdir -p "$DEST"
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT

      azcopy login --identity >/tmp/azcopy-login.log 2>&1
      azcopy copy "https://${storage_account_name}.blob.core.windows.net/${release_container_name}/latest.zip" "$TMP/latest.zip" --output-type text
      unzip -o "$TMP/latest.zip" -d "$DEST"

      python3 -m venv "$DEST/.venv"
      "$DEST/.venv/bin/pip" install --quiet --upgrade pip
      "$DEST/.venv/bin/pip" install --quiet -r "$DEST/requirements.txt"
      systemctl restart todo-backend
      echo "$(date -u +%FT%TZ) deployed backend" >> /var/log/todoapp-deploy.log

mounts:
  - ["//${storage_account_name}.file.core.windows.net/${file_share_name}", "/mnt/tododata", "cifs", "credentials=/etc/smbcredentials/tododata.cred,serverino,nosharesock,actimeo=30,mfsymlinks,_netdev", "0", "0"]

runcmd:
  - mkdir -p /mnt/tododata
  - mount -a
  - curl -sL https://aka.ms/downloadazcopy-v10-linux -o /tmp/azcopy.tar.gz
  - mkdir -p /tmp/azcopy_extract
  - tar -xzf /tmp/azcopy.tar.gz -C /tmp/azcopy_extract --strip-components=1
  - cp /tmp/azcopy_extract/azcopy /usr/local/bin/azcopy
  - chmod +x /usr/local/bin/azcopy
  - systemctl daemon-reload
  - systemctl enable todo-backend
  - /opt/deploy/deploy-backend.sh || echo "initial deploy skipped - no release artifact published yet"
