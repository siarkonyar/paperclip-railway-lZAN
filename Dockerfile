# Thin wrapper over the official image: adds first-boot config + automatic
# bootstrap-CEO invite so a Railway deploy needs no shell access.
ARG PAPERCLIP_IMAGE_TAG=latest
FROM ghcr.io/paperclipai/paperclip:${PAPERCLIP_IMAGE_TAG}

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Railway's edge proxy sits in front of the service; public auth mode is the
# only safe choice for an internet-facing URL.
ENV PAPERCLIP_DEPLOYMENT_MODE=authenticated \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=public \
    PORT=3100 \
    TRUST_PROXY=1

# Upstream ENTRYPOINT (tini -> docker-entrypoint.sh) is inherited: it fixes
# volume ownership as root, then drops to `node` before running this CMD. Our
# script must stay here, not in ENTRYPOINT: the volume is writable by agent
# processes, so any root-run file handling in it is a privilege escalation.
CMD ["railway-entrypoint.sh", "node", "--import", "./server/node_modules/tsx/dist/loader.mjs", "server/dist/index.js"]
