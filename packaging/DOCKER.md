# PDS APT Repository Docker Container

This directory contains a Docker setup to create a containerized APT repository hosting the PDS package using `aptly`.

## Overview

The container provides:

- ✅ **APT Repository**: Fully functional APT repository with `aptly`
- ✅ **Web Server**: Nginx serving repository files and metadata
- ✅ **GPG Signing**: Automatically signs packages with generated GPG key
- ✅ **Setup Script**: Provides easy repository installation for users
- ✅ **Health Checks**: Built-in health monitoring
- ✅ **Multi-platform**: Supports AMD64 and ARM64 architectures

## Quick Start

### Running the Container

```bash
# Run the latest version
docker run -d \
  --name pds-apt-repo \
  -p 8080:80 \
  your-username/pds-apt-repo:latest

# Access the repository
curl http://localhost:8080/
```

### Adding Repository to Your System

```bash
# Add GPG key
curl -fsSL http://your-host:8080/pds-repo.gpg | \
  sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null

# Add repository
echo "deb [signed-by=/usr/share/keyrings/pds-repo.gpg] http://your-host:8080/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/pds-repo.list

# Update and install
sudo apt update
sudo apt install pds
```

## Repository Setup

Standard APT repository setup - no scripts needed! Just use normal APT commands:

```bash
# Add GPG key
curl -fsSL http://your-host:8080/pds-repo.gpg | \
  sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null

# Add repository
echo "deb [signed-by=/usr/share/keyrings/pds-repo.gpg] http://your-host:8080/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/pds-repo.list

# Update and install
sudo apt update
sudo apt install pds
```

## Container Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Repository information page |
| `/apt/` | APT repository files |
| `/pds-repo.gpg` | GPG public key |
| `/health` | Health check endpoint |

## Building the Container

### Prerequisites

1. **Built PDS Package**: The `.deb` package must be in `./dist/` directory
2. **Docker Buildx**: For multi-platform builds

### Build Process

```bash
# Ensure package is built
cd packaging/
make build

# Build container
docker build -t pds-apt-repo .

# Or build multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-username/pds-apt-repo:latest \
  --push .
```

### CI/CD Integration

The container is automatically built and pushed when:
1. PDS package is successfully built
2. Release is created on main branch
3. All tests pass

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| None | This container requires no configuration | N/A |

### Volumes

| Path | Description |
|------|-------------|
| `/var/lib/aptly/.aptly` | APT repository data |
| `/var/www/html` | Web server content |
| `/etc/nginx` | Nginx configuration |

### Ports

| Port | Description |
|------|-------------|
| `80` | HTTP web server |

## Deployment Examples

### Docker Compose

```yaml
version: '3.8'
services:
  pds-apt-repo:
    image: your-username/pds-apt-repo:latest
    ports:
      - "8080:80"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pds-apt-repo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pds-apt-repo
  template:
    metadata:
      labels:
        app: pds-apt-repo
    spec:
      containers:
      - name: pds-apt-repo
        image: your-username/pds-apt-repo:latest
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: pds-apt-repo-service
spec:
  selector:
    app: pds-apt-repo
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

### Cloud Run (Google Cloud)

```bash
# Deploy to Cloud Run
gcloud run deploy pds-apt-repo \
  --image your-username/pds-apt-repo:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 80
```

## Security Considerations

1. **GPG Keys**: Container generates ephemeral GPG keys. For production, consider mounting persistent keys.
2. **HTTPS**: Use a reverse proxy (nginx, traefik, cloudflare) for HTTPS termination.
3. **Access Control**: Consider adding authentication for package publishing.
4. **Network**: Run on private networks when possible.

## Monitoring

### Health Checks

```bash
# Container health
curl http://your-host:8080/health

# Repository functionality
curl http://your-host:8080/apt/stable/Release
```

### Logs

```bash
# Container logs
docker logs pds-apt-repo

# Nginx access logs
docker exec pds-apt-repo tail -f /var/log/nginx/access.log

# Nginx error logs
docker exec pds-apt-repo tail -f /var/log/nginx/error.log
```

## Troubleshooting

### Common Issues

1. **Package not found**:
   ```bash
   # Check if package is in repository
   curl http://your-host:8080/apt/stable/main/binary-all/Packages
   ```

2. **GPG verification failed**:
   ```bash
   # Re-download GPG key
   curl -fsSL http://your-host:8080/pds-repo.gpg | \
     sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null
   ```

3. **Container won't start**:
   ```bash
   # Check logs
   docker logs pds-apt-repo
   
   # Check if package files exist
   docker run --rm your-username/pds-apt-repo:latest ls -la /tmp/packages/
   ```

### Debug Commands

```bash
# Inspect repository structure
docker exec -it pds-apt-repo su - aptly -c "aptly repo show pds"

# Check nginx configuration
docker exec pds-apt-repo nginx -t

# Verify GPG key
docker exec pds-apt-repo su - aptly -c "gpg --list-keys"
```

## Development

### Local Testing

```bash
# Build and test locally
make build
docker build -t pds-apt-repo:test .
docker run -d --name test-repo -p 8080:80 pds-apt-repo:test

# Test repository setup
curl -fsSL http://localhost:8080/pds-repo.gpg | sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/pds-repo.gpg] http://localhost:8080/apt/ stable main" | sudo tee /etc/apt/sources.list.d/pds-repo.list

# Install and test package
sudo apt update && sudo apt install pds
pds doctor
```

### Adding New Packages

To add more packages to the repository:

1. Build additional `.deb` files
2. Copy them to the `dist/` directory
3. Rebuild the container
4. The `aptly` configuration will automatically include all `.deb` files

## Contributing

1. Test changes with local Docker builds
2. Ensure health checks pass
3. Verify repository functionality with real APT clients
4. Update documentation for any configuration changes

## License

This Docker configuration is part of the PDS project and follows the same license terms.
