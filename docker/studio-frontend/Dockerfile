FROM node:20-bookworm-slim

ARG STUDIO_REV=eb52643b62429ee1a3f94e94ef06f38fc13dfcbb
ARG BACKEND_URL=http://backend:8001
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_IGNORE_BUILD_ERRORS=1 \
    BACKEND_URL=${BACKEND_URL} \
    PORT=3000 \
    HOSTNAME=0.0.0.0

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/Heroesjouney/AIMovieStudiov2.git /src/studio \
    && git -C /src/studio checkout --detach "${STUDIO_REV}"

WORKDIR /src/studio/frontend
RUN npm ci --include=dev || npm install --include=dev
RUN npm run build

EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=10 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["npm", "run", "start"]
