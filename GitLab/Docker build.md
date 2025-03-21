Building Docker Images in GitLab CI/CD Using Docker-in-Docker (DIND)

Now that we've set up unit testing and code coverage jobs in our GitLab CI/CD pipeline, the next step is to build a Docker image and push it to a container registry. In this guide, we'll go through the process of containerization in GitLab CI/CD, covering key concepts like stages, jobs, services (DIND), dependencies, and dynamic image tagging.


---

1. Defining a New Stage: containerization

In GitLab CI/CD, pipelines are divided into stages, where each stage represents a different phase of the CI/CD process. Since we want to build and push a Docker image, we'll create a new stage called containerization.

stages:
  - test
  - coverage
  - containerization


---

2. Creating the Docker Build Job

We now create a new job named docker_build that belongs to the containerization stage.

docker_build:
  stage: containerization
  image: docker:24.05

Why Do We Need a Specific Docker Image?

The docker:24.05 image provides a lightweight environment with the Docker CLI installed.

It enables us to run Docker commands like docker build, docker tag, and docker push inside the CI/CD pipeline.



---

3. Running Docker Commands Inside a Docker Container

By default, GitLab CI/CD runners do not have access to the Docker daemon. This means you cannot run Docker commands inside a job unless you provide a way to enable Docker inside the container.

Solution: Using Docker-in-Docker (DIND)

To allow our job to run Docker commands, we need to use Docker-in-Docker (DIND) as a service.

services:
    - name: docker:24.05-dind

What is Docker-in-Docker (DIND)?

DIND runs a separate Docker daemon inside a container.

This enables GitLab jobs to execute Docker commands, even if the runner itself does not have Docker installed.

It is useful when:

Building and pushing Docker images inside a GitLab pipeline.

Testing applications that rely on Docker containers.




---

4. Defining the Build Script

Now that we've set up our job with the correct image and services, let's define the script that will run inside this job.

script:
    - docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .
    - docker images

Explanation of the Commands

1. docker build -t my-docker-user/my-app:$CI_PIPELINE_ID .

docker build builds an image from the Dockerfile at the root of the repository.

-t assigns a tag to the image.

my-docker-user/my-app:$CI_PIPELINE_ID

my-docker-user/my-app: Name of the Docker image.

$CI_PIPELINE_ID: A GitLab predefined variable that ensures each build gets a unique tag.




2. docker images

Lists all available Docker images in the pipeline.





---

5. Understanding Dependencies in GitLab CI/CD

By default, GitLab downloads artifacts from previous jobs. However, the docker_build job does not require any artifacts from unit testing or code coverage jobs.

To optimize performance, we specify empty dependencies:

dependencies: []

Why Use dependencies: []?

It prevents downloading artifacts from previous jobs.

It speeds up the job execution.



---

6. Running the Pipeline and Checking Logs

Once the pipeline runs, the logs show the following steps:

1. Starting the Docker-in-Docker Service

The pipeline initializes the Docker-in-Docker service, allowing Docker commands to run inside the container.



2. Building the Docker Image

The job executes the docker build command, using the Dockerfile located at the root of the repository.

Example Dockerfile:


FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
ENV APP_PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]

The pipeline builds this image in steps:

Pulls the node:18-alpine base image.

Creates the working directory /app.

Copies package files and installs dependencies.

Copies the application source code.

Defines environment variables.

Exposes port 3000.

Specifies the start command (node server.js).




3. Displaying the Docker Image

The docker images command lists the built image:


REPOSITORY             TAG         IMAGE ID       CREATED         SIZE
my-docker-user/my-app  12345       abcdef123456   10 seconds ago  120MB

Here, 12345 represents $CI_PIPELINE_ID, ensuring a unique tag for every build.





---

7. Summary of the Pipeline Flow


---

8. What’s Next?

Now that the Docker image is built successfully, the next steps are:

1. Testing the Docker Image in a new pipeline job before pushing.


2. Pushing the Image to a container registry like Docker Hub or GitLab Container Registry.




---

Final YAML File

Here is the complete GitLab CI/CD configuration for building a Docker image:

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


---

Conclusion

We created a new containerization stage.

We added a Docker build job (docker_build).

We used Docker-in-Docker (DIND) to run Docker commands inside the pipeline.

We tagged the image dynamically using $CI_PIPELINE_ID.

We optimized the pipeline using dependencies: [].


Next up: Testing the Docker Image before pushing it to the registry!

