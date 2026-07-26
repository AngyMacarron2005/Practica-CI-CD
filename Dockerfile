# Etapa 1: Construcción y Pruebas
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# El build fallará aquí si las pruebas de inventario-app no pasan
RUN npm test 

# Etapa 2: Imagen final ligera
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/public ./public
COPY --from=builder /app/data ./data
COPY --from=builder /app/*.js ./
EXPOSE 3000
CMD ["npm", "start"]git add .