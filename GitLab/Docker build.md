# Building Docker Images in GitLab CI/CD Using Docker-in-Docker (DIND)

In this detailed guide, we’ll walk through the process of building Docker images in a GitLab CI/CD pipeline using Docker-in-Docker (DIND). Assuming you’ve already set up unit testing and code coverage jobs, we’ll now focus on adding a containerization step to build a Docker image. We’ll cover key concepts like stages, jobs, services, dependencies, and dynamic image tagging, ensuring you understand each part of the process.

---

## 1. Defining a New Stage: `containerization`

GitLab CI/CD pipelines are organized into **stages**, which define the sequence of tasks in your workflow (e.g., testing, building, deploying). To build a Docker image, we’ll introduce a new stage called `containerization`. This stage will run after the existing `test` and `coverage` stages, maintaining a logical progression.

Here’s how you define the stages in your `.gitlab-ci.yml` file:

```yaml
stages:
  - test
  - coverage
  - containerization
```

- **`test`**: Runs unit tests.
- **`coverage`**: Checks code coverage.
- **`containerization`**: Builds the Docker image.

Each stage depends on the successful completion of the previous one, ensuring that only code passing tests and coverage checks gets containerized.

---

## 2. Creating the Docker Build Job

Next, we create a job called `docker_build` within the `containerization` stage. This job will handle building the Docker image.

Here’s the basic job definition:

```yaml
docker_build:
  stage: containerization
  image: docker:24.05
```

### Why Use `docker:24.05`?

- The `image` keyword specifies the container environment where the job runs.
- `docker:24.05` is a lightweight Docker image that includes the **Docker CLI** (Command Line Interface). This allows us to run commands like `docker build` and `docker images` within the job.
- Using a specific version (e.g., `24.05`) ensures consistency across pipeline runs.

---

## 3. Running Docker Commands Inside a Docker Container with Docker-in-Docker (DIND)

By default, GitLab CI/CD runners don’t have access to a Docker daemon, which is required to execute Docker commands. To solve this, we use **Docker-in-Docker (DIND)** as a service.

Add this to the `docker_build` job:

```yaml
services:
  - name: docker:24.05-dind
```

### What is Docker-in-Docker (DIND)?

- **DIND** runs a Docker daemon inside a separate container alongside your job.
- This setup allows the `docker_build` job (running in the `docker:24.05` image) to communicate with the Docker daemon in the `docker:24.05-dind` service.
- It’s particularly useful in CI/CD environments where the runner itself might be a Docker container, and direct access to the host’s Docker daemon isn’t available.

### When is DIND Useful?

- Building and pushing Docker images in a pipeline.
- Running or testing applications that depend on Docker containers.

With DIND, the job can now execute Docker commands seamlessly.

---

## 4. Defining the Build Script

The `script` section specifies the commands to run inside the `docker_build` job. Here’s what we’ll use:

```yaml
script:
  - docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .
  - docker images
```

### Explanation of the Commands

#### 1. `docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .`

- **`docker build`**: Builds a Docker image based on the `Dockerfile` in the current directory (`.`).
- **`-t`**: Tags the image with a name and version.
- **`my-docker-user/my-app:$CI_PIPELINE_ID`**:
  - `my-docker-user`: Your Docker Hub username (replace with your own).
  - `my-app`: The name of your application.
  - `$CI_PIPELINE_ID`: A GitLab predefined variable that assigns a unique number to each pipeline run (e.g., `12345`). This ensures every image has a unique tag, avoiding conflicts.

#### 2. `docker images`

- Lists all Docker images available in the container after the build.
- This step confirms that the image was created successfully and displays details like the repository, tag, and size.

---

## 5. Optimizing with Dependencies

By default, GitLab CI/CD downloads artifacts (e.g., files or reports) from previous jobs into the current job. However, the `docker_build` job doesn’t need artifacts from the `test` or `coverage` stages—it only requires the repository code and the `Dockerfile`.

To optimize performance, we specify empty dependencies:

```yaml
dependencies: []
```

### Why Use `dependencies: []`?

- Prevents unnecessary artifact downloads.
- Speeds up job execution by reducing overhead.

---

## 6. Running the Pipeline and Checking Logs

When you trigger the pipeline, here’s what happens in the `docker_build` job:

### Step 1: Starting the Docker-in-Docker Service

- The `docker:24.05-dind` service starts, initializing a Docker daemon inside a container.
- The `docker:24.05` image (where the job runs) connects to this daemon to execute Docker commands.

### Step 2: Building the Docker Image

- The `docker build` command executes, following the instructions in your `Dockerfile`.

#### Example `Dockerfile`

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package.json package.lock.json ./
RUN npm install
COPY . .
ENV APP_PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]
```

The build process:
1. Pulls the `node:18-alpine` base image (a lightweight Node.js environment).
2. Sets the working directory to `/app`.
3. Copies `package.json` and `package-lock.json`, then runs `npm install` to install dependencies.
4. Copies the rest of the application code.
5. Sets the `APP_PORT` environment variable to `3000`.
6. Exposes port `3000` for the app.
7. Defines the startup command: `node server.js`.

### Step 3: Displaying the Docker Image

- The `docker images` command outputs something like this:

```
REPOSITORY             TAG         IMAGE ID       CREATED         SIZE
my-docker-user/my-app  12345       abcdef123456   10 seconds ago  120MB
```

- `12345` is the `$CI_PIPELINE_ID`, making each build’s tag unique.

---

## 7. Summary of the Pipeline Flow

The pipeline now consists of three stages:
- **`test`**: Executes unit tests (e.g., `unit_test` job).
- **`coverage`**: Verifies code coverage (e.g., `code_coverage` job).
- **`containerization`**: Builds the Docker image (`docker_build` job).

Each stage runs sequentially, ensuring that the Docker image is only built if tests pass and coverage requirements are met.

---

## 8. What’s Next?

Now that the Docker image is built, consider these next steps:

### 1. Testing the Docker Image
- Add a job to run the image in a container and test it (e.g., check if the app starts correctly on port `3000`).
- Example script:
  ```yaml
  script:
    - docker run -d -p 3000:3000 my-docker-user/my-app:$CI_PIPELINE_ID
    - sleep 5  # Wait for the app to start
    - curl http://localhost:3000  # Test the app
  ```

### 2. Pushing to a Container Registry
- After testing, push the image to a registry like Docker Hub or GitLab Container Registry.
- First, log in to Docker Hub:
  ```yaml
  script:
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    - docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .
    - docker push my-docker-user/my-app:$CI_PIPELINE_ID
  ```
  - Use GitLab variables (`$DOCKER_USERNAME`, `$DOCKER_PASSWORD`) to securely store credentials.

---

## Final `.gitlab-ci.yml` File

Here’s the complete configuration:

```yaml
stages:
  - test
  - coverage
  - containerization

unit_test:
  stage: test
  script:
    - echo "Running unit tests"
  artifacts:
    reports:
      junit: test-results.xml

code_coverage:
  stage: coverage
  script:
    - echo "Checking code coverage"

docker_build:
  stage: containerization
  image: docker:24.05
  services:
    - name: docker:24.05-dind
  script:
    - docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .
    - docker images
  dependencies: []
```

---

## Conclusion

In this guide, we:
- Created a `containerization` stage for building Docker images.
- Defined a `docker_build` job using the `docker:24.05` image.
- Enabled Docker commands with Docker-in-Docker (DIND) via the `docker:24.05-dind` service.
- Built and tagged the image dynamically with `$CI_PIPELINE_ID`.
- Optimized the job by setting `dependencies: []`.

This setup ensures your Docker image is built reliably and efficiently in GitLab CI/CD. The next steps—testing the image and pushing it to a registry—will prepare it for deployment. Happy containerizing!
