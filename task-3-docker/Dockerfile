FROM node:latest

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

EXPOSE 3000

USER node

ENTRYPOINT ["node", "server.js"]
