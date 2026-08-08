# ============================================================================
# Multi-stage Dockerfile for xavifortes.com (Astro)
#
# Stage 1 (builder): Node 24 Alpine — installs deps and runs `astro build`
# Stage 2 (runtime): nginx Alpine — serves the static dist/ with hardened config
#
# Final image is typically ~25MB and has zero Node.js surface area at runtime.
# ============================================================================

# ---- Stage 1: Build --------------------------------------------------------
FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files first for layer caching
COPY package.json package-lock.json* ./

# Install dependencies (ci = reproducible, no lockfile update)
RUN npm ci --frozen-lockfile

# Copy source
COPY . .

# Build Astro static site
RUN npm run build

# ---- Stage 2: Runtime ------------------------------------------------------
FROM nginx:mainline-alpine AS runtime

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy hardened nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built site from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Non-root user
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

# Healthcheck — nginx responds on root path
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/ > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
