FROM node:18-alpine

WORKDIR /app

# Install basic dependencies
RUN apk add --no-cache bash curl

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev --legacy-peer-deps

# Copy source code
COPY src ./src

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S authuser -u 1001

# Set permissions
RUN chown -R authuser:nodejs /app
USER authuser

# Expose port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3002/health || exit 1

# Start server
CMD ["npm", "start"]