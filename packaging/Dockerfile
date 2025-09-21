FROM ubuntu:noble

# Install aptly and dependencies
RUN apt-get update && \
    apt-get install -y \
        aptly \
        gpg \
        nginx \
        supervisor \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Create aptly user and directories
RUN useradd -m -s /bin/bash aptly && \
    mkdir -p /var/lib/aptly/.gnupg && \
    chown -R aptly:aptly /var/lib/aptly

# Copy configuration files
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy package files and setup repository
COPY dist/*.deb /tmp/packages/

# Configure aptly and create repository as aptly user
USER aptly
WORKDIR /var/lib/aptly

# Configure aptly
RUN echo '{"rootDir": "/var/lib/aptly/.aptly", "downloadConcurrency": 4, "downloadSpeedLimit": 0, "architectures": [], "dependencyFollowSuggests": false, "dependencyFollowRecommends": false, "dependencyFollowAllVariants": false, "dependencyFollowSource": false, "dependencyVerboseResolve": false, "gpgDisableSign": false, "gpgDisableVerify": false, "gpgProvider": "gpg", "downloadSourcePackages": false, "skipLegacyPool": true, "ppaDistributorID": "ubuntu", "ppaCodename": ""}' > /var/lib/aptly/.aptly.conf

# Generate GPG key for signing (non-interactive)
RUN gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: PDS APT Repository
Name-Email: noreply@pds.local
Expire-Date: 0
%no-protection
%commit
EOF

# Create and populate repository
RUN aptly repo create -distribution=stable -component=main pds && \
    aptly repo add pds /tmp/packages/ && \
    aptly publish repo pds

# Switch back to root for final setup
USER root

# Remove nginx default site and enable our config
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Link aptly public directory to nginx
RUN ln -sf /var/lib/aptly/.aptly/public /var/www/html/apt

# Export GPG public key to web directory
RUN su - aptly -c "gpg --armor --export > /var/www/html/pds-repo.gpg"

# Set proper ownership
RUN chown -R www-data:www-data /var/www/html

# Clean up
RUN rm -rf /tmp/packages

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
