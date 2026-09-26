FROM node:20-bookworm-slim

ARG BACKEND_URL=http://backend:8001
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_IGNORE_BUILD_ERRORS=1 \
    BACKEND_URL=${BACKEND_URL} \
    PORT=3000 \
    HOSTNAME=0.0.0.0

WORKDIR /src/studio/frontend
COPY vendor/AIMovieStudiov2/frontend/package.json vendor/AIMovieStudiov2/frontend/package-lock.json* ./
RUN npm ci --include=dev || npm install --include=dev
COPY vendor/AIMovieStudiov2/frontend ./
RUN npm run build

EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=10 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["npm", "run", "start"]
