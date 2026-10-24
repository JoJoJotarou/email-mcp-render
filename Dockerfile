# Thin wrapper around the upstream image (same version as the reviewed source:
# codefuturist/email-mcp v0.6.0). Render builds this from your GitHub repo.
# Pin by digest for reproducibility if you like:
#   FROM ghcr.io/codefuturist/email-mcp:0.6.0@sha256:<digest>
FROM ghcr.io/codefuturist/email-mcp:0.6.0@sha256:e6b6891f34bad25303a110a958cb736f322812889a91db13a0886adf32b84b86

USER root
COPY render-entrypoint.sh /usr/local/bin/render-entrypoint.sh
RUN chmod 0755 /usr/local/bin/render-entrypoint.sh
USER node

# 512 MB instance: keep V8's heap well below the container limit.
ENV NODE_ENV=production \
    NODE_OPTIONS=--max-old-space-size=256 \
    XDG_CONFIG_HOME=/home/node/.config \
    XDG_STATE_HOME=/home/node/.local/state \
    XDG_CACHE_HOME=/home/node/.cache

# Render injects $PORT (default 10000); the entrypoint binds 0.0.0.0:$PORT.
EXPOSE 10000
ENTRYPOINT ["/usr/local/bin/render-entrypoint.sh"]
CMD []
