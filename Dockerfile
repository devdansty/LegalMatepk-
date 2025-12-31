# Use official Node image
FROM node:20-alpine

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy rest of the code
COPY . .

# Expose your app port
EXPOSE 3000

# Start the app
CMD ["npm", "start"]