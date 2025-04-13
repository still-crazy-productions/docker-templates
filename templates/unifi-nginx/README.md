# 🐳 UniFi & Nginx Dockerized Setup with SSL

_A practical, careful, and repeatable guide._

---

## 🎯 Objective

Deploy UniFi Network Application securely behind Dockerized Nginx using Let's Encrypt for SSL.

---

## 🖥️ Initial Debian Setup (DigitalOcean Droplet)

**1. Install Docker & Docker Compose**

```bash
sudo apt update
sudo apt install docker.io docker-compose -y
sudo usermod -aG docker $USER
```

_Reboot or re-login to apply the Docker group._

---

## 🌐 Docker Network

**2. Create Docker network**

```bash
docker network create proxy
```

---

## 📂 Directory Structure

```bash
sudo mkdir -p /opt/stacks/{nginx-proxy,dcci-unifi}
sudo mkdir -p /opt/volumes/nginx-proxy/{certs,conf.d,stream.d,vhost.d,html}
sudo mkdir -p /opt/volumes/dcci-unifi/{app,db}
```

---

## 🚦 Docker Compose Setup

### **UniFi Setup**

**3. Docker Compose for UniFi**: `/opt/stacks/dcci-unifi/compose.yaml`

```yaml
services:
  unifi-db:
    image: mongo:7.0
    container_name: dcci-unifi-db
    volumes:
      - /opt/volumes/dcci-unifi/db:/data/db
    networks:
      - dcci-unifi-network

  unifi-app:
    image: lscr.io/linuxserver/unifi-network-application:latest
    container_name: dcci-unifi-app
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - MONGO_USER=unifi
      - MONGO_PASS=yourpassword
      - MONGO_DBNAME=unifi
    ports:
      - 8443
    networks:
      - dcci-unifi-network
      - proxy
    volumes:
      - /opt/volumes/dcci-unifi/app:/config

networks:
  proxy:
    external: true
  dcci-unifi-network:
```

Start UniFi:
```bash
cd /opt/stacks/dcci-unifi
docker compose up -d
```

---

### **Nginx Setup**

**4. Docker Compose for Nginx**: `/opt/stacks/nginx-proxy/compose.yaml`

```yaml
services:
  nginx-proxy:
    image: nginx:stable-alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/volumes/nginx-proxy/nginx.conf:/etc/nginx/nginx.conf:ro
      - /opt/volumes/nginx-proxy/conf.d:/etc/nginx/conf.d
      - /opt/volumes/nginx-proxy/stream.d:/etc/nginx/stream.d
      - /opt/volumes/nginx-proxy/certs:/etc/nginx/certs
      - /opt/volumes/nginx-proxy/html:/usr/share/nginx/html
    networks:
      - proxy

networks:
  proxy:
    external: true
```

Start Nginx:
```bash
cd /opt/stacks/nginx-proxy
docker compose up -d
```

---

## 🔐 Let's Encrypt (acme.sh) Setup

**5. Install `acme.sh`**

```bash
sudo su
curl https://get.acme.sh | sh -s email=your-email@example.com
source ~/.bashrc
```

**Issue SSL Certificate**

Stop nginx temporarily:

```bash
docker stop nginx-proxy
```

Issue the certificate:

```bash
~/.acme.sh/acme.sh --issue --standalone -d dcci.unifi.daileycomputer.com --keylength ec-256 --server letsencrypt
```

Deploy SSL certificates:

```bash
mkdir -p /opt/volumes/nginx-proxy/certs/live/dcci.unifi.daileycomputer.com

~/.acme.sh/acme.sh --install-cert -d dcci.unifi.daileycomputer.com \
  --ecc \
  --key-file /opt/volumes/nginx-proxy/certs/live/dcci.unifi.daileycomputer.com/privkey.pem \
  --fullchain-file /opt/volumes/nginx-proxy/certs/live/dcci.unifi.daileycomputer.com/fullchain.pem \
  --reloadcmd "docker restart nginx-proxy"
```

Restart nginx:

```bash
docker start nginx-proxy
```

---

## ⚙️ Nginx Configuration

**6. Nginx Reverse Proxy Config**: `/opt/volumes/nginx-proxy/conf.d/unifi.conf`

```nginx
server {
    listen 443 ssl;
    server_name dcci.unifi.daileycomputer.com;

    ssl_certificate /etc/nginx/certs/live/dcci.unifi.daileycomputer.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/live/dcci.unifi.daileycomputer.com/privkey.pem;

    location / {
        proxy_pass https://dcci-unifi-app:8443;
        proxy_ssl_verify off;
        proxy_ssl_server_name on;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 60;
        proxy_send_timeout 300;
    }
}

server {
    listen 80;
    server_name dcci.unifi.daileycomputer.com;
    return 301 https://$host$request_uri;
}
```

Restart nginx to apply changes:

```bash
docker restart nginx-proxy
```

---

## 🚧 Notes & Next Steps

- Documented fully for ease of restoration.
- SSL certs auto-renew with `acme.sh` cron job.
- Verify all backups regularly.

You're now securely serving UniFi via Nginx proxy with valid SSL! 🎉

