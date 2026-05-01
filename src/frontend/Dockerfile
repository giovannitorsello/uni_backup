FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --legacy-peer-deps
#RUN npm ci
COPY . .

RUN npx quasar build

FROM nginx:1.25-alpine
COPY --from=build /app/dist/spa /usr/share/nginx/html
COPY nginx-spa.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
