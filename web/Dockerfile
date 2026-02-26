FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

# Static frontend build
COPY --from=build /app/dist /app/dist

# Built-in API server (no external deps)
COPY server /app/server

ENV PORT=80
EXPOSE 80

CMD ["node", "/app/server/server.js"]
