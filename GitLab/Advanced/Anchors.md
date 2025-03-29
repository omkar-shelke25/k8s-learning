

### What Are YAML Anchors?

YAML anchors (`&`) and aliases (`*` or `<<`) are part of the YAML specification, not unique to GitLab, and they allow you to define a piece of configuration once and reuse it elsewhere in the same file. In GitLab CI/CD, anchors are particularly useful for reducing duplication in `.gitlab-ci.yml`, similar to `extends`, but with some key differences:

- **Anchors**: Pure YAML feature, works within a single file, copies content verbatim or merges it.
- **Extends**: GitLab-specific, designed for job inheritance, supports merging rules, and works across files with `include`.

Anchors can be applied at:
1. **Job Level**: Reuse an entire job’s configuration.
2. **Keyword Level**: Reuse specific fields (e.g., `services`, `before_script`).

#### Syntax:
- **`&name`**: Defines an anchor with a unique name.
- **`*name`**: References the anchor, copying its content.
- **`<<: *name`**: Merges the anchor’s content into the current hash (e.g., a job), allowing overrides.

---

### Why Use Anchors?

- **Reduce Duplication**: Centralize repeated settings.
- **Single-File Scope**: Unlike `extends` with `include`, anchors work within one `.gitlab-ci.yml`.
- **Granular Control**: Reuse entire jobs or specific keywords.

---

### Example Scenario: Refactoring Kubernetes Deployment Jobs

Let’s revisit your pipeline. You’ve got a `test` stage with `unit_tests` and `code_coverage` (commented out for now), and you’re focusing on deployment jobs (`dev_deploy` and `stage_deploy`) that depend on Docker jobs (`docker_build`, `docker_test`, `docker_push`). Both deployment jobs share common setup code (`image`, `dependencies`, `before_script`), and you want to:
1. Use the `needs` keyword to start `dev_deploy` as soon as `docker_push` completes.
2. Reuse configuration with anchors.

#### Original `.gitlab-ci.yml` (Before Anchors)
```yaml
stages:
  - test
  - containerize
  - deploy

variables:
  DOCKER_REGISTRY: "docker.io"
  IMAGE_NAME: "my-app"

# Hidden job from previous session (not executed unless extended)
.prepare_nodejs_env:
  image: node:18-alpine
  before_script:
    - npm ci

# Commented out for this session
# unit_tests:
#   extends: .prepare_nodejs_env
#   stage: test
#   script:
#     - npm test

# code_coverage:
#   extends: .prepare_nodejs_env
#   stage: test
#   script:
#     - npm run coverage

docker_build:
  stage: containerize
  image: docker:20
  services:
    - docker:dind
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .

docker_test:
  stage: containerize
  image: docker:20
  script:
    - docker run $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA /bin/sh -c "echo Testing"

docker_push:
  stage: containerize
  image: docker:20
  services:
    - docker:dind
  script:
    - docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $DOCKER_REGISTRY
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA

dev_deploy:
  stage: deploy
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push
  before_script:
    - kubectl config use-context dev-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: dev
    url: https://dev.my-app.com

stage_deploy:
  stage: deploy
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push
  before_script:
    - kubectl config use-context stage-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: staging
    url: https://stage.my-app.com
```

**Observations:**
- **Duplication**: `dev_deploy` and `stage_deploy` share `image`, `dependencies`, and `before_script` structure (only the context differs).
- **Pipeline Flow**: By default, `deploy` stage waits for all `containerize` jobs to finish.
- **Goal**: Use `needs` to optimize flow and anchors to reuse configuration.

---

### Step 1: Adding the `needs` Keyword

First, let’s make `dev_deploy` start as soon as `docker_push` completes, bypassing other `containerize` jobs.

**Updated `dev_deploy`:**
```yaml
dev_deploy:
  stage: deploy
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push
  before_script:
    - kubectl config use-context dev-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: dev
    url: https://dev.my-app.com
  needs:
    - docker_push
```

**What Changed?**
- **Needs**: `needs: [docker_push]` tells GitLab to run `dev_deploy` immediately after `docker_push` succeeds, ignoring `docker_build` and `docker_test` completion (though `dependencies` ensures the image is available).
- **Visualization**: In the pipeline UI, `dev_deploy` will show a direct dependency arrow from `docker_push`, not the entire `containerize` stage.

---

### Step 2: Using Anchors for Reusable Configuration

Now, let’s refactor `dev_deploy` and `stage_deploy` to reuse their common setup (`image`, `dependencies`, `before_script`) using anchors. We’ll define a hidden job with an anchor and reference it.

#### Refactored `.gitlab-ci.yml` with Anchors
```yaml
stages:
  - test
  - containerize
  - deploy

variables:
  DOCKER_REGISTRY: "docker.io"
  IMAGE_NAME: "my-app"

# Hidden job with anchor for deployment setup
.prepare_deploy_env: &deploy_base
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push
  before_script:
    - kubectl config use-context placeholder  # Placeholder, overridden later

docker_build:
  stage: containerize
  image: docker:20
  services:
    - docker:dind
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .

docker_test:
  stage: containerize
  image: docker:20
  script:
    - docker run $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA /bin/sh -c "echo Testing"

docker_push:
  stage: containerize
  image: docker:20
  services:
    - docker:dind
  script:
    - docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $DOCKER_REGISTRY
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA

dev_deploy:
  <<: *deploy_base  # Merge the anchor
  stage: deploy
  before_script:    # Override the placeholder
    - kubectl config use-context dev-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: dev
    url: https://dev.my-app.com
  needs:
    - docker_push

stage_deploy:
  <<: *deploy_base  # Merge the anchor
  stage: deploy
  before_script:    # Override the placeholder
    - kubectl config use-context stage-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: staging
    url: https://stage.my-app.com
```

**What’s Happening?**
1. **Anchor Definition**:
   - `.prepare_deploy_env: &deploy_base` defines a hidden job with an anchor named `deploy_base`.
   - It includes the shared `image`, `dependencies`, and a placeholder `before_script`.

2. **Anchor Reference**:
   - `<<: *deploy_base` merges the entire `deploy_base` configuration into `dev_deploy` and `stage_deploy`.
   - The `<<` operator is a YAML merge key, combining the anchor’s hash into the job.

3. **Overrides**:
   - Both jobs override `before_script` with their specific `kubectl` context (`dev-cluster` or `stage-cluster`).
   - `script`, `environment`, and `needs` are unique to each job and added on top.

4. **Hidden Job**:
   - `.prepare_deploy_env` doesn’t run in the pipeline because it’s hidden (starts with a dot).

---

### Merging Behavior with Anchors

Unlike `extends`, which has GitLab-specific merging rules, anchors follow YAML’s native behavior:
- **`<<: *name`**: Merges the anchor’s content into the job. If the job redefines a key (e.g., `before_script`), the job’s value completely replaces the anchor’s value (no appending for arrays).
- **`*name` (without `<<`)**: Copies the anchor’s content as-is, but only works for non-hash contexts (e.g., a single field like `services`).

#### Merged Result (Full Config View):
For `dev_deploy`:
```yaml
dev_deploy:
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push
  before_script:
    - kubectl config use-context dev-cluster
  stage: deploy
  script:
    - kubectl apply -f k8s/deployment.yaml
  environment:
    name: dev
    url: https://dev.my-app.com
  needs:
    - docker_push
```

---

### Keyword-Level Anchors

You can also define anchors for specific fields. Let’s reuse just the `services` configuration from a Docker job.

#### Example with Keyword-Level Anchor
```yaml
.docker_base: &docker_services
  services:
    - docker:dind

docker_build:
  stage: containerize
  image: docker:20
  <<: *docker_services  # Merge services
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .

docker_push:
  stage: containerize
  image: docker:20
  <<: *docker_services  # Merge services
  script:
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
```

**What Happens?**
- `&docker_services` defines an anchor for the `services` field.
- `<<: *docker_services` merges it into both jobs, adding the `docker:dind` service.

---

### Combining Job and Keyword Anchors

You can mix both approaches in one job.

#### Example:
```yaml
.job_base: &job_anchor
  image: bitnami/kubectl:1.23
  dependencies:
    - docker_push

.before_script_base: &before_anchor
  before_script:
    - kubectl config use-context placeholder

dev_deploy:
  <<: *job_anchor        # Merge entire job
  <<: *before_anchor     # Merge before_script
  stage: deploy
  before_script:         # Override
    - kubectl config use-context dev-cluster
  script:
    - kubectl apply -f k8s/deployment.yaml
```

**Note**: Multiple `<<` merges can get tricky; ensure keys don’t conflict, or later ones override earlier ones.

---

### Anchors vs. `extends`

| Feature             | Anchors                     | Extends                     |
|---------------------|-----------------------------|-----------------------------|
| **Scope**           | Single `.gitlab-ci.yml`     | Works across files with `include` |
| **Merging**         | YAML-native (override)      | GitLab-specific (merge arrays, hashes) |
| **Syntax**          | `&`, `*`, `<<`              | `extends:`                  |
| **Hidden Jobs**     | Optional                    | Required                    |

**When to Use Anchors?**
- Small pipelines in one file.
- When you don’t need `include` or complex merging.

---

### Running the Pipeline

1. **Commit**: “Add anchors for deployment jobs and needs for dev_deploy.”
2. **Pipeline UI**: Shows `docker_build > docker_test > docker_push > dev_deploy` and `stage_deploy` (latter waits for full `containerize` stage unless `needs` is added).
3. **Logs**: Confirm `dev_deploy` uses `bitnami/kubectl:1.23` and runs after `docker_push`.

---

### Advantages

- **Reduced Lines**: From ~20 duplicated lines to 1 anchor definition.
- **Consistency**: Update `.prepare_deploy_env`, and both jobs reflect changes.
- **Flexibility**: Override specific parts (e.g., `before_script`) while reusing the rest.

---

### Conclusion

YAML anchors provide a lightweight, file-local way to reuse configuration in GitLab CI/CD. By defining `.prepare_deploy_env: &deploy_base`, you centralized the deployment setup and merged it into `dev_deploy` and `stage_deploy` with `<<: *deploy_base`. Pairing this with `needs` optimized the pipeline flow, making `dev_deploy` faster. Anchors shine for simple reuse within one file, complementing `extends` for broader scenarios.

Let me know if you want to explore keyword-level anchors further, compare with `extends` in more detail, or tweak this example!
