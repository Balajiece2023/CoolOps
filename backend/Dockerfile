FROM node:20-alpine AS builder

WORKDIR /app

# Install OpenSSL 3 so Prisma detects linux-musl-openssl-3.0.x accurately
RUN apk add --no-cache openssl libc6-compat

COPY package*.json ./
COPY tsconfig.json ./
COPY prisma ./prisma/

RUN npm ci

COPY src ./src
COPY assets ./assets
RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Runtime OpenSSL 3 + CA certificates required by Prisma engines and outbound HTTPS requests
RUN apk add --no-cache openssl libc6-compat ca-certificates

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci --omit=dev

# Reuse pre-generated Prisma client (linux-musl-openssl-3.0.x) and pinned Prisma CLI
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/assets ./assets

RUN mkdir -p ./node_modules/.bin ./uploads && ln -sf ../prisma/build/index.js ./node_modules/.bin/prisma

EXPOSE 4000

CMD ["sh", "-c", "node ./node_modules/prisma/build/index.js migrate deploy && node dist/src/index.js"]
