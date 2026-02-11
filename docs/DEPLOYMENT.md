# Angle - Deployment Guide

## Overview

This guide covers deploying Angle to production environments. The application can be deployed to various platforms including Fly.io, Render, Heroku, or self-hosted servers.

## Prerequisites

- PostgreSQL database (version 12+)
- Elixir 1.15+
- Node.js 16+ (for asset compilation)
- Domain name (optional but recommended)
- SSL certificate (Let's Encrypt recommended)

## Environment Configuration

### Required Environment Variables

Create a `.env` file or configure these in your hosting platform:

```bash
# Application
SECRET_KEY_BASE=your_secret_key_base_here_64_chars_minimum
PHX_HOST=your-domain.com

# Database
DATABASE_URL=postgresql://user:password@host:5432/angle_prod

# JWT Signing Secret
JWT_SECRET=your_jwt_signing_secret_here

# Email (SMTP)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
FROM_EMAIL=noreply@your-domain.com

# Optional
PORT=4000
POOL_SIZE=10
```

### Generating Secrets

Generate secure secrets using:

```bash
# SECRET_KEY_BASE (64+ characters)
mix phx.gen.secret

# JWT_SECRET
mix phx.gen.secret 32
```

## Pre-deployment Checklist

### 1. Update Configuration

**config/runtime.exs** - Ensure production config is correct:

```elixir
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      """

  config :angle, Angle.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :angle, AngleWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
```

### 2. Build Assets

```bash
# Install dependencies
mix deps.get --only prod
cd assets && npm install && cd ..

# Compile assets
MIX_ENV=prod mix assets.deploy

# Compile application
MIX_ENV=prod mix compile
```

### 3. Database Migrations

```bash
# Generate migrations from Ash resources
MIX_ENV=prod mix ash.codegen

# Run migrations
MIX_ENV=prod mix ash_postgres.migrate

# Seed database (optional)
MIX_ENV=prod mix run priv/repo/seeds.exs
```

### 4. Create Release

```bash
MIX_ENV=prod mix release
```

## Deployment Options

## Option 1: Fly.io (Recommended)

Fly.io provides easy deployment with PostgreSQL database and automatic SSL.

### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
iwr https://fly.io/install.ps1 -useb | iex
```

### 2. Login

```bash
fly auth login
```

### 3. Initialize Fly App

```bash
fly launch
```

Follow the prompts:
- Choose app name
- Select region
- Create PostgreSQL database (recommended)
- Don't deploy yet

### 4. Configure Secrets

```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set JWT_SECRET=$(mix phx.gen.secret 32)
fly secrets set SMTP_HOST=smtp.sendgrid.net
fly secrets set SMTP_USERNAME=apikey
fly secrets set SMTP_PASSWORD=your_api_key
fly secrets set FROM_EMAIL=noreply@your-domain.com
```

### 5. Create fly.toml

```toml
app = "your-app-name"
primary_region = "sjc"

[build]
  [build.args]
    MIX_ENV = "prod"

[env]
  PHX_HOST = "your-app-name.fly.dev"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 1024

[[statics]]
  guest_path = "/app/priv/static"
  url_prefix = "/assets"
```

### 6. Create Dockerfile

```dockerfile
FROM hexpm/elixir:1.15.7-erlang-26.1.2-debian-bookworm-20231009-slim as build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Install npm dependencies
COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm install

# Copy assets
COPY priv priv
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Copy source code
COPY lib lib

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# Start a new build stage
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Copy built release
COPY --from=build --chown=nobody:root /app/_build/${MIX_ENV}/rel/angle ./

USER nobody

CMD ["/app/bin/server"]
```

### 7. Deploy

```bash
fly deploy
```

### 8. Run Migrations

```bash
fly ssh console
/app/bin/angle eval "Angle.Release.migrate"
```

### 9. Scale (Optional)

```bash
# Scale to 2 VMs
fly scale count 2

# Increase memory
fly scale memory 2048
```

## Option 2: Render

### 1. Create Web Service

- Go to [render.com](https://render.com)
- Click "New +" → "Web Service"
- Connect your repository
- Configure:
  - **Name**: angle
  - **Environment**: Elixir
  - **Build Command**: `mix deps.get && mix assets.deploy && mix compile`
  - **Start Command**: `mix phx.server`

### 2. Add PostgreSQL Database

- Click "New +" → "PostgreSQL"
- Link to your web service

### 3. Set Environment Variables

In Render dashboard:
- `SECRET_KEY_BASE`
- `JWT_SECRET`
- `MIX_ENV=prod`
- `PHX_HOST=your-app.onrender.com`

### 4. Deploy

Render will automatically deploy on git push.

## Option 3: Self-Hosted (Ubuntu/Debian)

### 1. Prepare Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential git curl postgresql nginx

# Install Elixir
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt update
sudo apt install -y esl-erlang elixir
```

### 2. Setup PostgreSQL

```bash
sudo -u postgres psql

CREATE DATABASE angle_prod;
CREATE USER angle WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE angle_prod TO angle;
\q
```

### 3. Deploy Application

```bash
# Clone repository
cd /opt
sudo git clone https://github.com/yourname/angle.git
cd angle

# Build release
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release

# Create systemd service
sudo nano /etc/systemd/system/angle.service
```

**angle.service:**
```ini
[Unit]
Description=Angle Auction Platform
After=network.target

[Service]
Type=simple
User=angle
WorkingDirectory=/opt/angle
Environment="MIX_ENV=prod"
Environment="SECRET_KEY_BASE=your_secret"
Environment="DATABASE_URL=postgresql://angle:password@localhost/angle_prod"
Environment="PHX_HOST=your-domain.com"
Environment="PORT=4000"
ExecStart=/opt/angle/_build/prod/rel/angle/bin/angle start
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Start service
sudo systemctl daemon-reload
sudo systemctl enable angle
sudo systemctl start angle
sudo systemctl status angle
```

### 4. Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/angle
```

**angle nginx config:**
```nginx
upstream angle {
    server 127.0.0.1:4000;
}

server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://angle;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files
    location ~* ^/assets/ {
        proxy_pass http://angle;
        expires 1y;
        add_header Cache-Control "public";
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/angle /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Setup SSL with Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Database Management

### Running Migrations

```bash
# Fly.io
fly ssh console
/app/bin/angle eval "Angle.Release.migrate"

# Render
# SSH into console and run:
/app/bin/angle eval "Angle.Release.migrate"

# Self-hosted
cd /opt/angle
MIX_ENV=prod mix ash_postgres.migrate
```

### Database Backup

```bash
# Fly.io
fly postgres backup create

# Self-hosted
pg_dump angle_prod > backup_$(date +%Y%m%d).sql
```

### Restore Database

```bash
# Self-hosted
psql angle_prod < backup_20240115.sql
```

## Monitoring

### Health Checks

Add health check endpoint in router:

```elixir
# lib/angle_web/router.ex
scope "/health" do
  get "/", AngleWeb.HealthController, :index
end

# lib/angle_web/controllers/health_controller.ex
defmodule AngleWeb.HealthController do
  use AngleWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
```

### Logging

View logs:

```bash
# Fly.io
fly logs

# Render
# View in dashboard

# Self-hosted
sudo journalctl -u angle -f
```

### Performance Monitoring

Consider adding:
- [AppSignal](https://appsignal.com/)
- [Sentry](https://sentry.io/) for error tracking
- [New Relic](https://newrelic.com/)

## Email Configuration

### SendGrid

```bash
# Set environment variables
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
FROM_EMAIL=noreply@your-domain.com
```

### Mailgun

```bash
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=postmaster@your-domain.com
SMTP_PASSWORD=your_mailgun_password
FROM_EMAIL=noreply@your-domain.com
```

### AWS SES

```bash
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=your_aws_access_key
SMTP_PASSWORD=your_aws_secret
FROM_EMAIL=noreply@your-domain.com
```

## SSL/TLS Configuration

### Let's Encrypt (Free)

```bash
sudo certbot --nginx -d your-domain.com
sudo certbot renew --dry-run
```

### Custom Certificate

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Strong SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
}
```

## Scaling

### Vertical Scaling

Increase server resources:

```bash
# Fly.io
fly scale memory 2048
fly scale vm shared-cpu-2x

# Self-hosted
# Upgrade server instance
```

### Horizontal Scaling

Run multiple instances:

```bash
# Fly.io
fly scale count 3

# Self-hosted with load balancer
# Setup HAProxy or nginx load balancer
```

### Database Scaling

- Enable connection pooling (already configured)
- Add read replicas for read-heavy workloads
- Use PgBouncer for connection management

## Security Checklist

- [ ] SSL/TLS enabled (HTTPS)
- [ ] Environment variables secured
- [ ] Database credentials rotated
- [ ] Firewall configured
- [ ] Security headers enabled
- [ ] CSRF protection enabled (default in Phoenix)
- [ ] Rate limiting implemented
- [ ] Regular security updates
- [ ] Database backups automated
- [ ] Monitoring and alerting setup

## Troubleshooting

### Application Won't Start

Check logs and environment variables:

```bash
# Verify all required env vars are set
echo $SECRET_KEY_BASE
echo $DATABASE_URL

# Check database connection
mix run -e "Angle.Repo.query!(\"SELECT 1\")"
```

### Database Connection Issues

```bash
# Test connection
psql $DATABASE_URL

# Check pool size
# Increase POOL_SIZE if needed
```

### Asset Loading Issues

```bash
# Rebuild assets
MIX_ENV=prod mix assets.deploy

# Check static file serving
ls -la priv/static/assets
```

### Memory Issues

```bash
# Monitor memory usage
fly metrics

# Increase memory allocation
fly scale memory 2048
```

## Rollback Procedure

### Fly.io

```bash
# List releases
fly releases

# Rollback to previous
fly releases rollback
```

### Git-based Deployments

```bash
git revert HEAD
git push origin main
```

## Performance Optimization

### Enable Gzip Compression

Already enabled in Phoenix for static assets.

### CDN Integration

Use CloudFlare or AWS CloudFront for static assets:

```elixir
# config/runtime.exs
config :angle, AngleWeb.Endpoint,
  static_url: [
    scheme: "https",
    host: "cdn.your-domain.com"
  ]
```

### Database Query Optimization

- Add indexes for frequently queried fields
- Use database connection pooling
- Implement caching for expensive queries

### Asset Optimization

Already handled by `mix assets.deploy`:
- CSS minification
- JS bundling and minification
- Asset fingerprinting

## Maintenance

### Regular Updates

```bash
# Update dependencies
mix deps.update --all

# Run tests
mix test

# Deploy
git push
```

### Database Maintenance

```bash
# Vacuum database
psql $DATABASE_URL -c "VACUUM ANALYZE;"

# Check database size
psql $DATABASE_URL -c "SELECT pg_size_pretty(pg_database_size('angle_prod'));"
```

## Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Fly.io Elixir Documentation](https://fly.io/docs/elixir/)
- [Render Elixir Guide](https://render.com/docs/deploy-elixir)
