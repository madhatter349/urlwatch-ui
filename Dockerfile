# Use a specific version of node:19-alpine for both build and runtime stages to ensure consistency
FROM node:19-alpine AS BUILD_IMAGE

# Set the working directory in the container
WORKDIR /usr/src/app

# Install Python, pip, and other dependencies
# The apk add command is used to install packages on Alpine Linux
RUN apk add --update python3 py3-pip && \
    python3 -m ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools

# Copy package management files
COPY package.json .
COPY pnpm-lock.yaml .

# Install a specific version of pnpm that is compatible with your lockfileVersion
RUN npm install -g pnpm@6

# Install dependencies using the frozen lockfile to ensure reproducibility
RUN pnpm install --frozen-lockfile

# Copy the rest of the application's source code
COPY . .

# Build the application
RUN pnpm build

# Remove development dependencies to keep the image size small
RUN pnpm prune --prod

# Install urlwatch
RUN pip3 install urlwatch

# Start a new stage from node:19-alpine to keep the image size down
FROM node:19-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Install Python and pip in the final image as well
RUN apk add --update python3 py3-pip && \
    python3 -m ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools

# Copy built artifacts and necessary files from the build stage
COPY --from=BUILD_IMAGE /usr/src/app/build ./build
COPY --from=BUILD_IMAGE /usr/src/app/node_modules ./node_modules
COPY --from=BUILD_IMAGE /usr/src/app/package.json ./package.json

# Copy the urlwatch installation from the build stage
# Since urlwatch and its dependencies are installed in the Python site-packages,
# we need to copy the entire Python site-packages directory from the build stage to the final stage.
COPY --from=BUILD_IMAGE /usr/lib/python3.*/site-packages/ /usr/lib/python3.*/site-packages/

# Set environment variables
ENV NODE_ENV=production
ENV HOST=0.0.0.0

# Use the PORT environment variable for compatibility with Railway's dynamic port assignment
EXPOSE $PORT

CMD [ "npm", "start" ]
