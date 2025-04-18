
### Key Requirements:
- **Localhost Only**:
  - The client’s `VITE_BACKEND_URL` is hardcoded as `http://localhost:49152`, resolved by the browser on the host (`127.0.0.1:49152`) and routed to the server container via Docker’s port mapping (`49152:49152`).
  - The server listens on port `49152`, and the client listens on port `49153`.
- **No Environment Variables**:
  - Ports (`49152`, `49153`) and `VITE_BACKEND_URL` are hardcoded in the Dockerfiles.
- **Security**:
  - Non-root users, restrictive permissions, minimal `node:22-alpine` image, and non-guessable ports.
- **Comments**:
  - Explain `localhost` (`127.0.0.1`) and internal Docker IPs (e.g., `172.18.0.x`).
- **Assumptions**:
  - The `server` and `client` use `npx serve` to serve the `dist` folder.
  - The `public` folder is included but can be removed if not needed (noted in comments).
  - `package.json` includes `serve` as a dependency.

### Project Structure
```
project-root/
├── server/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
├── client/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
└── docker-compose.yml
```

### Dockerfiles
#### Server Dockerfile (`./server/Dockerfile`)
```dockerfile
# Stage 1: Build the project
FROM node:22-alpine AS builder

WORKDIR /build

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./

# Install build dependencies securely and efficiently
RUN npm ci --prefer-offline --no-audit --progress=false && \
    rm -rf /root/.npm /root/.node-gyp

# Copy the rest of the source code
COPY . .

# Build the application
RUN npm run build

# Prune dev dependencies for a leaner image
RUN npm prune --omit=dev

# Stage 2: Serve the application
FROM node:22-alpine AS runner

# Add labels for better maintainability
LABEL maintainer="Omkar Shelke <omkar.shelke@proton.me>"
LABEL version="1.0"
LABEL description="Secure Node.js server for localhost"

WORKDIR /app

# Create non-root user and group with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -G appgroup -H -D appuser && \
    mkdir -p /app && \
    chown -R appuser:appgroup /app

# Copy necessary artifacts with correct permissions
COPY --from=builder --chown=appuser:appgroup /build/dist ./dist/
COPY --from=builder --chown=appuser:appgroup /build/public ./public/
# Note: Remove the above line if `public` folder is not needed (e.g., Vite merges into `dist`).
COPY --from=builder --chown=appuser:appgroup /build/node_modules ./node_modules/
COPY --from=builder --chown=appuser:appgroup /build/package.json ./package.json
COPY --from=builder --chown=appuser:appgroup /build/package-lock.json* ./package-lock.json

# Switch to non-root user
USER appuser

# Restrict file system access
RUN chmod -R 500 ./dist ./public ./node_modules && \
    chmod 400 ./package.json ./package-lock.json*
# Note: If `public` folder is not copied, remove `./public` from the chmod command.

# Expose non-standard port
EXPOSE 49152
# Localhost: The server listens on port 49152, accessible at `http://localhost:49152`
# or `http://127.0.0.1:49152` on the host via Docker Compose port mapping.
# IP Address: Inside the Docker network, the server has a dynamic IP (e.g., 172.18.0.2),
# but `localhost:49152` is used for host access, not internal IPs.

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:49152 || exit 1
# Localhost: Checks `http://localhost:49152` inside the server container (container-internal).
# IP Address: Equivalent to `127.0.0.1:49152` within the container.

# Start the server on hardcoded port
CMD ["npx", "serve", "-s", "dist", "-l", "49152", "--no-clipboard", "--no-port-switching"]
# Hardcodes port 49152, ensuring the server is accessible at `http://localhost:49152`
# on the host. No environment variables are used.
```

#### Client Dockerfile (`./client/Dockerfile`)
```dockerfile
# Stage 1: Build the project
FROM node:22-alpine AS builder

WORKDIR /build

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./

# Install build dependencies securely and efficiently
RUN npm ci --prefer-offline --no-audit --progress=false && \
    rm -rf /root/.npm /root/.node-gyp

# Copy the rest of the source code
COPY . .

# Create .env file for Vite build with localhost URL
RUN echo "VITE_BACKEND_URL=http://localhost:49152" > .env
# Localhost: Hardcodes VITE_BACKEND_URL for local development. The frontend, running
# in the browser on the host, uses `http://localhost:49152` to reach the server.
# IP Address: The browser resolves `localhost` to 127.0.0.1, routed to the server
# container via Docker’s port mapping. Internal container IPs (e.g., 172.18.0.2) are
# not used, as API requests originate from the host’s browser.

# Build the application
RUN npm run build

# Prune dev dependencies for a leaner image
RUN npm prune --omit=dev

# Stage 2: Serve the application
FROM node:22-alpine AS runner

# Add labels for better maintainability
LABEL maintainer="Omkar Shelke <omkar.shelke@proton.me>"
LABEL version="1.0"
LABEL description="Secure Node.js client for localhost"

WORKDIR /app

# Create non-root user and group with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -G appgroup -H -D appuser && \
    mkdir -p /app && \
    chown -R appuser:appgroup /app

# Copy necessary artifacts with correct permissions
COPY --from=builder --chown=appuser:appgroup /build/dist ./dist/
COPY --from=builder --chown=appuser:appgroup /build/public ./public/
# Note: Remove the above line if `public` folder is not needed.
COPY --from=builder --chown=appuser:appgroup /build/node_modules ./node_modules/
COPY --from=builder --chown=appuser:appgroup /build/package.json ./package.json
COPY --from=builder --chown=appuser:appgroup /build/package-lock.json* ./package-lock.json

# Switch to non-root user
USER appuser

# Restrict file system access
RUN chmod -R 500 ./dist ./public ./node_modules && \
    chmod 400 ./package.json ./package-lock.json*
# Note: If `public` folder is not copied, remove `./public` from the chmod command.

# Expose non-standard port
EXPOSE 49153
# Localhost: The client listens on port 49153, accessible at `http://localhost:49153`
# or `http://127.0.0.1:49153` on the host via port mapping.
# IP Address: The client has a dynamic IP (e.g., 172.18.0.3) in the Docker network,
# but `localhost:49153` is used for host access.

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:49153 || exit 1
# Localhost: Checks `http://localhost:49153` inside the client container.

# Start the server on hardcoded port
CMD ["npx", "serve", "-s", "dist", "-l", "49153", "--no-clipboard", "--no-port-switching"]
# Hardcodes port 49153, ensuring the client is accessible at `http://localhost:49153`
# on the host. No environment variables are used.
```

### Docker Compose File (`docker-compose.yml`)
```yaml
version: '3.9'

services:
  server:
    container_name: code-sync-server
    build:
      context: ./server
      dockerfile: Dockerfile
      target: runner
      # Builds the server using `./server/Dockerfile`, targeting the `runner` stage.
      # No environment variables; port 49152 is hardcoded in the Dockerfile using
      # `npx serve -s dist -l 49152`.
      # Localhost: The server is accessible at `http://localhost:49152` or
      # `http://127.0.0.1:49152` on the host via port mapping.
      # IP Address: Inside the Docker network, the server has a dynamic IP
      # (e.g., 172.18.0.2), but `localhost:49152` is used for host access, not internal IPs.
    networks:
      - code-sync
      # Joins the `code-sync` bridge network for container isolation.
      # IP Address: Docker assigns a dynamic IP (e.g., 172.18.0.2) to the server.
      # Internal communication could use `code-sync-server:49152`, but the client’s
      # frontend uses `localhost:49152` (resolved by the browser on the host).
      # Localhost: `localhost` in `VITE_BACKEND_URL` is for browser-to-host communication,
      # not container-to-container.
    ports:
      - "49152:49152"
      # Maps host port 49152 to container port 49152, enabling access at
      # `http://localhost:49152` or `http://127.0.0.1:49152` from the host.
      # Localhost: The browser resolves `localhost` to 127.0.0.1, and Docker routes
      # requests to the server container.
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:49152"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
      # Verifies the server is running at `http://localhost:49152` inside the container.
      # Localhost: Refers to the container’s internal loopback (127.0.0.1), not the host.
      # IP Address: Equivalent to the container’s loopback IP.

  client:
    container_name: code-sync-client
    build:
      context: ./client
      dockerfile: Dockerfile
      target: runner
      # Builds the client using `./client/Dockerfile`, targeting the `runner` stage.
      # No environment variables; `VITE_BACKEND_URL=http://localhost:49152` and port 49153
      # are hardcoded in the Dockerfile.
      # Localhost: The client is accessible at `http://localhost:49153`, and its frontend
      # makes API requests to `http://localhost:49152` (server).
      # IP Address: The client has a dynamic IP (e.g., 172.18.0.3), but `localhost:49153`
      # is used for host access, and `localhost:49152` is resolved by the browser.
    networks:
      - code-sync
      # Joins the `code-sync` network for isolation, but the frontend (browser) uses
      # `localhost:49152` for API requests, resolved by the host’s port mapping.
      # IP Address: Internal container IPs are not used for API requests, as they originate
      # from the browser on the host.
    ports:
      - "49153:49153"
      # Maps host port 49153 to container port 49153, enabling access at
      # `http://localhost:49153` or `http://127.0.0.1:49153` from the host.
      # Localhost: The browser accesses the client via `localhost:49153`.
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:49153"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
      # Verifies the client is running at `http://localhost:49153` inside the container.
      # Localhost: Refers to the container’s internal loopback.
    depends_on:
      server:
        condition: service_healthy
        # Ensures the client starts after the server is healthy (responding at
        # `http://localhost:49152` inside the server container).

networks:
  code-sync:
    driver: bridge
    name: code-sync
    # Creates an isolated bridge network for the server and client.
    # IP Address: Containers get dynamic IPs (e.g., 172.18.0.2, 172.18.0.3) in the
    # network. Service names (`code-sync-server`, `code-sync-client`) are used for
    # internal communication, but `VITE_BACKEND_URL=http://localhost:49152` is resolved
    # by the browser on the host, not the network.
    # Localhost: `localhost` in `VITE_BACKEND_URL` is for browser-to-host communication,
    # leveraging the host’s 127.0.0.1 and port mappings.
```

### Step-by-Step Guide: How It Works
#### Step 1: Project Structure
Ensure the project is organized as:
```
project-root/
├── server/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
├── client/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json (optional)
│   ├── src/ (or other source files)
│   └── public/ (if needed)
└── docker-compose.yml
```

- **Server**: Backend code, built into a `dist` folder via `npm run build`. Serves on `http://localhost:49152`.
- **Client**: Vite-based frontend, built into a `dist` folder, with API requests to `http://localhost:49152`. Serves on `http://localhost:49153`.
- **package.json**: Include `serve` in both:
  ```json
  "dependencies": {
    "serve": "^14.2.1"
  }
  ```

#### Step 2: Build the Images
Build the server and client images:
```bash
docker-compose build
```

**What Happens**:
- **Server**:
  - **Builder Stage**: Uses `node:22-alpine`, installs dependencies (`npm ci`), builds (`npm run build`), and prunes dev dependencies.
  - **Runner Stage**: Copies `dist`, `public`, `node_modules`, and `package*.json` as `appuser`. Sets restrictive permissions, exposes `49152`, and starts `npx serve -s dist -l 49152`.
  - **Localhost/IP**: Listens on `localhost:49152` (container-internal), mapped to `localhost:49152` or `127.0.0.1:49152` on the host. Internal IP (e.g., `172.18.0.2`) is not used for external access.
- **Client**:
  - **Builder Stage**: Same as server, but creates `.env` with `VITE_BACKEND_URL=http://localhost:49152` for Vite’s build.
  - **Runner Stage**: Copies artifacts, sets permissions, exposes `49153`, and starts `npx serve -s dist -l 49153`.
  - **Localhost/IP**: Listens on `localhost:49153` (container-internal), mapped to `localhost:49153` or `127.0.0.1:49153`. API requests to `localhost:49152` are resolved by the browser to `127.0.0.1:49152`.

#### Step 3: Run the Containers
Start the services in detached mode:
```bash
docker-compose up -d
```

**What Happens**:
- **Server**:
  - Runs `code-sync-server`, serving `dist` on port `49152` (internal).
  - Health check verifies `http://localhost:49152` (container-internal).
  - Accessible at `http://localhost:49152` or `http://127.0.0.1:49152` on the host.
- **Client**:
  - Waits for the server to be healthy (`condition: service_healthy`).
  - Runs `code-sync-client`, serving `dist` on port `49153` (internal).
  - Health check verifies `http://localhost:49153` (container-internal).
  - Accessible at `http://localhost:49153` or `http://127.0.0.1:49153` on the host.
- **Network**:
  - The `code-sync` bridge network assigns dynamic IPs (e.g., `172.18.0.2` for server, `172.18.0.3` for client).
  - API requests use `localhost:49152` (browser-resolved to `127.0.0.1:49152`), not internal IPs.
- **Localhost/IP**:
  - `localhost` in `VITE_BACKEND_URL` is resolved by the browser to `127.0.0.1:49152`, routed to the server via port mapping.
  - Internal IPs are irrelevant for API requests, as they originate from the host’s browser.

#### Step 4: Verify the Application
1. **Access the Client**:
   - Open a browser on the host and navigate to `http://localhost:49153` or `http://127.0.0.1:49153`.
   - The frontend loads from the client’s `dist`.
2. **Test API Calls**:
   - The frontend sends requests to `http://localhost:49152` (via `VITE_BACKEND_URL`).
   - The browser resolves `localhost` to `127.0.0.1:49152`, and Docker routes to the server.
   - Check DevTools (Network tab) for successful requests.
3. **Check Health**:
   - Verify containers are healthy:
     ```bash
     docker inspect --format='{{.State.Health.Status}}' code-sync-server
     docker inspect --format='{{.State.Health.Status}}' code-sync-client
     ```
     Should show `healthy`.
4. **View Logs**:
   - Check for errors:
     ```bash
     docker-compose logs
     ```

#### Step 5: Security Verification
1. **Vulnerability Scanning**:
   - Scan images:
     ```bash
     docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image code-sync-server
     docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image code-sync-client
     ```
2. **Firewall**:
   - Restrict access to `49152` and `49153`:
     ```bash
     ufw allow 49152/tcp
     ufw allow 49153/tcp
     ufw deny 1-49151
     ufw deny 49154-65535
     ```
3. **Security Features**:
   - Non-root user (`appuser`).
   - Restrictive permissions (`500` for `dist`, `public`, `node_modules`; `400` for `package*.json`).
   - Non-guessable ports (`49152`, `49153`).
   - Minimal `node:22-alpine` image.

#### Step 6: Troubleshooting
1. **Client Can’t Reach Server**:
   - Verify `http://localhost:49152` in the browser:
     ```bash
     curl http://localhost:49152
     ```
   - Check `dist` assets for `VITE_BACKEND_URL` (inspect client’s build output).
2. **Port Conflicts**:
   - If `49152` or `49153` is in use, choose other ports (e.g., `49154`, `49155`) in the 49152–65535 range and update the Dockerfiles and `docker-compose.yml`.
3. **Build Failures**:
   - Ensure Vite reads `.env` and `serve` is in `package.json`:
     ```json
     "dependencies": {
       "serve": "^14.2.1"
     }
     ```
   - Verify the `build` script in `package.json`.
4. **Health Check Failures**:
   - Check logs:
     ```bash
     docker-compose logs
     ```
   - Ensure `dist` contains `index.html` or the expected entry point.

#### Step 7: Cleanup
Stop and remove containers, images, and unused objects:
```bash
docker-compose down
docker rmi code-sync-server code-sync-client
docker system prune
```

### Notes:
- **Localhost and IP**:
  - `localhost` (`127.0.0.1`) in `VITE_BACKEND_URL` is resolved by the browser on the host, routed to the server via `49152:49152`.
  - Internal Docker IPs (e.g., `172.18.0.2`) are used for container-to-container communication but are irrelevant here, as API requests originate from the browser.
- **Public Folder**:
  - If `public` is not needed (e.g., Vite merges it into `dist`), remove the `COPY` and `chmod` references in the Dockerfiles:
    ```dockerfile
    # Remove:
    COPY --from=builder --chown=appuser:appgroup /build/public ./public/
    # Update:
    RUN chmod -R 500 ./dist ./node_modules && \
        chmod 400 ./package.json ./package-lock.json*
    ```
- **Custom Server**:
  - If using Express or another server, update the `CMD`:
    ```dockerfile
    CMD ["node", "server.js"]  # Ensure it listens on 49152 (server) or 49153 (client)
    ```
- **Development Setup**:
  - For live reloading, add volume mounts in a separate `docker-compose.dev.yml`:
    ```yaml
    services:
      server:
        volumes:
          - ./server:/app
      client:
        volumes:
          - ./client:/app
    ```
    Run:
    ```bash
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
    ```

This setup is tailored for localhost-only development, with detailed comments explaining `localhost` and IP address usage. Let me know if you need alternative ports, a custom server setup, or additional features like development configurations!
