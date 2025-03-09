In GitLab CI/CD, **artifacts** are files or directories created during a job that are saved and can be passed to subsequent jobs in the pipeline. Artifacts are commonly used to store build outputs, test reports, logs, or any other files that need to be shared between jobs or accessed after the pipeline completes.

---

### Key Points About Artifacts

1. **Purpose**:
   - Share files between jobs in the same pipeline.
   - Store files for later use (e.g., downloadable build outputs).
   - Pass test reports or logs to downstream jobs.

2. **Storage**:
   - Artifacts are stored by GitLab and can be downloaded from the pipeline interface.
   - They are automatically deleted after a configurable retention period (default is 30 days).

3. **Dependencies**:
   - Jobs can specify which artifacts to download using the `dependencies` or `needs` keywords.

4. **Types of Artifacts**:
   - **Regular Artifacts**: Files or directories created during a job.
   - **Reports**: Special artifacts used for parsing test results, code quality, etc.

---

### Basic Usage of Artifacts

Here’s an example of how to define and use artifacts in a `.gitlab-ci.yml` file:

```yaml
stages:
  - build
  - test

build_job:
  stage: build
  script:
    - echo "Building the application..."
    - mkdir -p build
    - echo "Build output" > build/output.txt
  artifacts:
    paths:
      - build/output.txt

test_job:
  stage: test
  script:
    - echo "Testing the application..."
    - cat build/output.txt
  dependencies:
    - build_job
```

---

### Explanation

1. **`build_job`**:
   - Runs in the `build` stage.
   - Creates a directory (`build`) and a file (`output.txt`).
   - Uses the `artifacts` keyword to specify that `build/output.txt` should be saved as an artifact.

2. **`test_job`**:
   - Runs in the `test` stage.
   - Uses the `dependencies` keyword to download the artifact (`build/output.txt`) from `build_job`.
   - Accesses the artifact during its execution.

---

### Advanced Usage of Artifacts

#### 1. **Excluding Files**
You can exclude specific files or directories from being saved as artifacts.

```yaml
artifacts:
  paths:
    - build/
  exclude:
    - build/temp/
```

---

#### 2. **Artifact Expiration**
You can set an expiration time for artifacts to control how long they are retained.

```yaml
artifacts:
  paths:
    - build/
  expire_in: 1 week
```

- **`expire_in`**: Specifies how long the artifacts should be kept (e.g., `1 week`, `2 days`, `6 hours`).

---

#### 3. **Artifacts for Reports**
GitLab supports special artifacts for reports, such as test results, code quality, and coverage. These reports are displayed in the GitLab UI.

```yaml
test_job:
  stage: test
  script:
    - echo "Running tests..."
    - echo "Test results" > test-results.xml
  artifacts:
    reports:
      junit: test-results.xml
```

- **`junit`**: Uploads the `test-results.xml` file as a JUnit test report, which is displayed in the GitLab UI.

---

#### 4. **Artifacts for Multiple Jobs**
You can pass artifacts between jobs in different stages or even within the same stage using `dependencies` or `needs`.

```yaml
stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo "Building the application..."
    - mkdir -p build
    - echo "Build output" > build/output.txt
  artifacts:
    paths:
      - build/

test_job:
  stage: test
  script:
    - echo "Testing the application..."
    - cat build/output.txt
  needs:
    - build_job

deploy_job:
  stage: deploy
  script:
    - echo "Deploying the application..."
    - cat build/output.txt
  needs:
    - build_job
```

---

#### 5. **Artifacts for Merge Requests**
You can configure artifacts to be created only for merge requests.

```yaml
build_job:
  stage: build
  script:
    - echo "Building the application..."
    - mkdir -p build
    - echo "Build output" > build/output.txt
  artifacts:
    paths:
      - build/
  only:
    - merge_requests
```

---

#### 6. **Artifacts for Tags**
You can configure artifacts to be created only for tagged commits.

```yaml
build_job:
  stage: build
  script:
    - echo "Building the application..."
    - mkdir -p build
    - echo "Build output" > build/output.txt
  artifacts:
    paths:
      - build/
  only:
    - tags
```

---

### Important Notes

1. **Artifact Size**:
   - GitLab has a default artifact size limit (e.g., 100 MB for free tiers). You can increase this limit in self-managed GitLab instances.

2. **Artifact Retention**:
   - Artifacts are automatically deleted after the retention period expires. You can configure this using `expire_in`.

3. **Artifact Download**:
   - Artifacts can be downloaded from the GitLab UI or via the API.

4. **Artifact Paths**:
   - Use absolute or relative paths to specify files or directories to include as artifacts.

---

### Example: Full Pipeline with Artifacts

Here’s an example of a full pipeline using artifacts:

```yaml
stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo "Building the application..."
    - mkdir -p build
    - echo "Build output" > build/output.txt
  artifacts:
    paths:
      - build/
    expire_in: 1 week

test_job:
  stage: test
  script:
    - echo "Testing the application..."
    - cat build/output.txt
  dependencies:
    - build_job

deploy_job:
  stage: deploy
  script:
    - echo "Deploying the application..."
    - cat build/output.txt
  needs:
    - build_job
```

---

### Summary

- Use `artifacts` to save and share files between jobs.
- Specify paths to include or exclude files.
- Use `expire_in` to control artifact retention.
- Use `reports` for special artifacts like test results.
- Combine `artifacts` with `dependencies` or `needs` for efficient pipeline workflows.

Let me know if you need further clarification or additional examples!
