FROM node:22-alpine
WORKDIR /app
COPY package.json server.mjs ./
EXPOSE 8787
ENV PORT=8787
CMD ["node","server.mjs"]
