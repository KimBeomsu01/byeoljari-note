FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts
COPY verifier.mjs ./
USER node
CMD ["node", "verifier.mjs"]
