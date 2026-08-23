#!/bin/bash
cat << 'EOF' > /data/nginx/proxy_host/golf_homelab-admin.conf
# ------------------------------------------------------------
# golf.homelab-admin.me -> Golf Swing Analyzer (192.168.110.51:8086)
# ------------------------------------------------------------

server {
  set $forward_scheme http;
  set $server         "192.168.110.51";
  set $port           8086;

  listen 80;
  listen [::]:80;

  listen 443 ssl;
  listen [::]:443 ssl;

  server_name golf.homelab-admin.me;

  http2 on;

  include /etc/nginx/conf.d/include/ssl-cache.conf;
  include /etc/nginx/conf.d/include/ssl-ciphers.conf;
  ssl_certificate /etc/letsencrypt/live/npm-3/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-3/privkey.pem;

  set $trust_forwarded_proto "F";
  include /etc/nginx/conf.d/include/force-ssl.conf;

  include /etc/nginx/conf.d/include/block-exploits.conf;

  client_max_body_size 0;
  proxy_read_timeout 3600s;
  proxy_send_timeout 3600s;
  send_timeout 3600s;

  location / {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Scheme $scheme;
    proxy_set_header X-Forwarded-Proto  $scheme;
    proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP          $remote_addr;
    proxy_pass       http://192.168.110.51:8086;
  }
}
EOF

nginx -t && nginx -s reload
