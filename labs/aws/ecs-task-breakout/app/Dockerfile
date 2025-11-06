FROM python:3.13-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# VULNERABILITY: Hardcoded database credentials in build-time ENV
# These remain in image history even after deletion
ENV DB_LEGACY_USER="postgres_admin"
ENV DB_LEGACY_PASSWORD="P@ssw0rd_H4rdc0d3d_2024!"
ENV DB_LEGACY_HOST="prod-legacy-db.internal.example.com"

# Development credentials that were supposed to be removed
RUN echo "INTERNAL_API_KEY=sk_prod_a1b2c3d4e5f6g7h8i9j0" > /tmp/dev_secrets.txt && \
    echo "ADMIN_PASSWORD=Sup3rS3cr3t!" >> /tmp/dev_secrets.txt && \
    echo "FLAG{ecr_image_layer_hardcoded_credentials_discovered}" >> /tmp/dev_secrets.txt

# "Clean up" credentials (still in layer history)
RUN rm -f /tmp/dev_secrets.txt

# Remove ENV vars (still in image history)
ENV DB_LEGACY_USER=""
ENV DB_LEGACY_PASSWORD=""
ENV DB_LEGACY_HOST=""

# Copy application
COPY app.py .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]