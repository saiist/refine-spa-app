# Keycloak for GCP Cloud Run
# Supports both development and production modes
# ARM64 to AMD64 cross-compilation ready

FROM quay.io/keycloak/keycloak:23.0.3

# Switch to keycloak user
USER keycloak

# Cloud Run optimized settings
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_HTTP_ENABLED=true
ENV KC_HOSTNAME_STRICT=false
ENV KC_PROXY=edge

# Build Keycloak for optimization
RUN /opt/keycloak/bin/kc.sh build

# Health check for Cloud Run
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health/ready || exit 1

# Expose port
EXPOSE 8080

# Entry point
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

# Default command (can be overridden for dev mode)
# Production: CMD ["start", "--optimized"]
# Development: CMD ["start-dev", "--http-port=8080"]
CMD ["start", "--optimized"]

# Build instructions:
# For ARM64 hosts (Apple Silicon, Windows ARM) targeting AMD64 Cloud Run:
# docker buildx build --platform linux/amd64 -t gcr.io/PROJECT/keycloak .
#
# For local development:
# docker build -t keycloak-local .
#
# For development mode deployment:
# Override CMD: ["start-dev", "--http-port=8080"]