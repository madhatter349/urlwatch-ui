# Use a specific version of node:19-alpine for both build and runtime stages to ensure consistency
FROM node:19-alpine AS BUILD_IMAGE

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package management files
COPY package.json .
COPY pnpm-lock.yaml .

# Install pnpm globally
RUN npm install -g pnpm

# Install dependencies using the frozen lockfile to ensure reproducibility
RUN pnpm install --frozen-lockfile

# Copy the rest of the application's source code
COPY . .

# Build the application
RUN pnpm build

# Remove development dependencies to keep the image size small
RUN pnpm prune --prod

# Start a new stage from node:19-alpine to keep the image size down
FROM node:19-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy built artifacts and necessary files from the build stage
COPY --from=BUILD_IMAGE /usr/src/app/build ./build
COPY --from=BUILD_IMAGE /usr/src/app/node_modules ./node_modules
COPY --from=BUILD_IMAGE /usr/src/app/package.json ./package.json

# Set environment variables
# Railway automatically sets NODE_ENV to production
# The HOST environment variable is set to 0.0.0.0 to allow connections from outside the container
ENV NODE_ENV=production
ENV HOST=0.0.0.0

# Railway dynamically assigns a port for your application to use. Use the PORT environment variable.
# Ensure your application is configured to listen on process.env.PORT.
# If your app listens on a fixed port (e.g., 3000), make sure to adjust it to use process.env.PORT.
EXPOSE $PORT

# Replace "npm start" with "node" command if your package.json's start script is not configured to use the built app.
CMD [ "npm", "start" ]
