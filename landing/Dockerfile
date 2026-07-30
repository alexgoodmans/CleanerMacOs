# ─────────────────────────────────────────────────────────────────────────────
# Again Cleaner — landing image (Vite/React SPA served by nginx)
#
# Build context is this directory (landing/). In Coolify: Base Directory
# /landing, Dockerfile /Dockerfile, exposed port 80.
#
# TLS is NOT handled here — the proxy in front (Traefik/Caddy) terminates
# HTTPS and forwards plain HTTP to this container. That is why the container
# config drops the cert paths and the HTTP→HTTPS redirect that the bare-metal
# template in deploy/nginx.conf still carries.
# ─────────────────────────────────────────────────────────────────────────────

FROM node:22-alpine AS build
WORKDIR /app

# Dependencies first: this layer is cached until the lockfile actually changes.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# `build` = tsc -b && vite build → dist/
RUN npm run build


FROM nginx:1.27-alpine

# security-headers.inc is shared with the bare-metal config; it is re-included
# in every location that sets its own add_header (nginx drops inherited ones).
COPY deploy/security-headers.inc /etc/nginx/conf.d/security-headers.inc
COPY deploy/nginx-docker.conf    /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/healthz || exit 1
