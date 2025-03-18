
## **Problem Statement**
You are tasked with creating a GitLab CI/CD pipeline to automate the build, test, Docker image creation, push, and deployment of a sample project. The project involves generating a simple text file using `cowsay` and handling Docker-based operations, followed by deployment to an EC2 instance. The pipeline should:

1. Build a sample text file using `cowsay`.
2. Test the generated file to confirm it contains the expected output.
3. Build a Docker image for the project.
4. Test the Docker container after building it.
5. Push the Docker image to a container registry.
6. Deploy the project to an EC2 instance.

The pipeline should:
- Trigger automatically when changes are pushed to the `main` branch.
- Trigger when a merge request includes changes to the `README.md` file.

---

## **Explanation of Code**

### **1. Workflow**
```yaml
workflow:
   name: Lab 2
   rules:
     - if: $CI_COMMIT_BRANCH == "main"
       when: always
     - if: $CI_PIPELINE_SOURCE == "merge_request_event"
       changes:
          paths: 
            - "README.md"
       when: always
```

### ➡️ **Concepts Explained:**
- `workflow`: Defines the overall pipeline configuration.
- `name`: The name of the pipeline (`Lab 2`).
- `rules`: Controls when the pipeline should run:
  - ✅ **First Rule**:
    - Runs the pipeline on any push to the `main` branch.
  - ✅ **Second Rule**:
    - Triggers the pipeline only if a merge request modifies the `README.md` file.

---

### **2. Stages**
```yaml
stages:
   - build
   - test
   - docker
   - deploy
```

### ➡️ **Concepts Explained:**
- `stages`: Defines the sequence in which jobs run.
- GitLab will execute stages in order:
  1. `build`
  2. `test`
  3. `docker`
  4. `deploy`

---

### **3. Variables**
```yaml
variables:
   USERNAME: "dockerUsername"
   REGISTRY: docker.io/$USERNAME
   IMAGE: lab2-demo-image
   VERSION: $CI_PIPELINE_ID
```

### ➡️ **Concepts Explained:**
- `variables`: Defines reusable environment variables.
  - `$USERNAME`: DockerHub username.
  - `$REGISTRY`: Docker registry path.
  - `$IMAGE`: Name of the Docker image.
  - `$VERSION`: Pipeline ID used as the image version.

---

### **4. Build Stage**
```yaml
build_file:
   stage: build
   image: ruby:2.7
   before_script:
      - gem install cowsay
   script:
      - >
         cowsay -f dragon "Run for cover, 
         I am a DRAGON....RAWR" >> dragon.txt
   artifacts:
      name: Dragon Text File
      paths:
         - dragon.txt
      when: on_success
      expire_in: 30 days
```

### ➡️ **Concepts Explained:**
- **Job Name**: `build_file`
- **Stage**: `build`
- **image**: Uses Ruby 2.7 Docker image.
- **before_script**:
  - Installs `cowsay` using `gem install`.
- **script**:
  - Uses `cowsay` to create a text file (`dragon.txt`) with a dragon message.
- **artifacts**:
  - Saves `dragon.txt` as a build artifact.
  - `when: on_success`: Saves only if the build succeeds.
  - `expire_in: 30 days`: Artifact retention period.

---

### **5. Test Stage**
```yaml
test_file:
   stage: test
   script:
      - |
         grep -i "dragon" dragon.txt
```

### ➡️ **Concepts Explained:**
- **Job Name**: `test_file`
- **Stage**: `test`
- **script**:
  - Checks if the generated file contains the word `"dragon"` (case-insensitive).
- If the test fails, the pipeline stops.

---

### **6. Docker Build Stage**
```yaml
docker_build:
    stage: docker
    script:
      - echo "docker build -t docker.io/$USERNAME/$IMAGE:$VERSION"
```

### ➡️ **Concepts Explained:**
- **Job Name**: `docker_build`
- **Stage**: `docker`
- **script**:
  - Builds a Docker image using the `docker build` command.
  - Uses pipeline variables to tag the image with `$VERSION`.

---

### **7. Docker Test Stage**
```yaml
docker_testing:
    stage: docker
    needs:
       - docker_build
    script:
      - echo "docker run -p 80:80 docker.io/$USERNAME/$IMAGE:$VERSION"
```

### ➡️ **Concepts Explained:**
- **Job Name**: `docker_testing`
- **Stage**: `docker`
- **needs**:
  - Ensures `docker_testing` runs only after `docker_build` finishes.
- **script**:
  - Runs the Docker container to check if the image works correctly.

---

### **8. Docker Push Stage**
```yaml
docker_push:
    stage: docker
    needs:
       - docker_testing
    script:
      - echo "docker login --username=dockerUsername --password=$DOCKER_PASSWORD"
      - echo "docker push docker.io/$USERNAME/$IMAGE:$VERSION" 
```

### ➡️ **Concepts Explained:**
- **Job Name**: `docker_push`
- **Stage**: `docker`
- **needs**:
  - Runs only after `docker_testing` is successful.
- **script**:
  - Logs in to DockerHub using environment variables.
  - Pushes the Docker image to the registry.

---

### **9. Deploy Stage**
```yaml
deploy_ec2:
   stage: deploy
   dependencies:
      - build_file
   script:
      - cat dragon.txt
      - echo "deploying ... .. ."
      - echo "Username - $USERNAME and Password - $PASSWORD"
```

### ➡️ **Concepts Explained:**
- **Job Name**: `deploy_ec2`
- **Stage**: `deploy`
- **dependencies**:
  - Makes sure `dragon.txt` artifact is available during deployment.
- **script**:
  - Displays the contents of `dragon.txt`.
  - Mock deployment step (no actual EC2 interaction shown).

---

## **How the Pipeline Flows**
### ✅ Trigger Conditions:
- On push to `main`.
- On merge request changes to `README.md`.

### 🚀 Stages Execution:
1. **Build Stage**: Generates a file using `cowsay`.
2. **Test Stage**: Checks the file for expected content.
3. **Docker Stage**:
   - Builds the Docker image.
   - Tests the Docker container.
   - Pushes the Docker image to the registry.
4. **Deploy Stage**: Deploys to an EC2 instance (mocked).

---

## **Potential Issues and Improvements**
✅ **Issues**:
- Docker commands are echoed but not executed — need to remove `echo` for real execution.  
- `DOCKER_PASSWORD` and `PASSWORD` should be stored securely as masked GitLab CI/CD secrets.  
- EC2 deployment is mocked — need to add actual deployment steps using `ssh` or Terraform.  

✅ **Improvements**:
- Add a `cleanup` job to remove unused Docker images.  
- Add logging for better traceability.  
- Add error handling to catch failures in Docker commands and deployment steps.  

---

## ✅ **Summary**
This pipeline demonstrates a complete CI/CD workflow involving build, test, Dockerization, and deployment. Once configured properly, it will automate the development lifecycle and streamline the deployment process. 🚀
