# Use a specific version of node:19-alpine for both build and runtime stages to ensure consistency
FROM node:19-alpine AS BUILD_IMAGE

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package management files
COPY package.json .
COPY pnpm-lock.yaml .

# Install a specific version of pnpm that is known to be compatible with lockfileVersion 5.4.
# Adjust the version as needed based on compatibility and testing.
RUN npm install -g pnpm@6

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

# Use the PORT environment variable to ensure compatibility with Railway's dynamic port assignment
EXPOSE $PORT

# Replace "npm start" with "node" command if your package.json's start script is not configured to use the built app.
CMD [ "npm", "start" ]
