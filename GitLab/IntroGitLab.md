

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">🌐 1. Pipeline</span>

#### **Definition**  
A pipeline is the **end-to-end automation engine** of GitLab CI/CD. It’s a structured sequence of tasks (jobs) executed in response to predefined events, guiding your code from a commit to a deployed product.

#### **Deep Dive**  
- **Configuration File**: The `.gitlab-ci.yml` is your pipeline’s DNA. It’s parsed by GitLab when a trigger fires, translating YAML into a runnable workflow. Missing this file? No pipeline runs.  
- **Triggers**: Pipelines aren’t static—they’re event-driven:  
  - **Push**: A `git push` to any branch can trigger it.  
  - **Merge Request**: Creating or updating an MR fires a pipeline to validate changes.  
  - **Scheduled**: Cron-like schedules (e.g., nightly builds) via GitLab’s UI.  
  - **Manual**: A “Run Pipeline” button in the UI for ad-hoc execution.  
  - **API/Webhooks**: External tools (e.g., Jenkins) can trigger via GitLab’s API.  
- **Workflow Rules**: The `workflow:rules` keyword acts as a gatekeeper. It evaluates conditions (e.g., branch names, variables) to decide if the pipeline should run or skip.  
  - Example: `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/` runs only for version tags like `v1.0.0`.  
- **Naming**: With `workflow:name`, you can dynamically label pipelines using variables like `$CI_COMMIT_REF_NAME` (branch name) or custom strings. This shines in dashboards with dozens of pipelines.  
- **Execution**: Pipelines run on **runners**—GitLab’s compute agents. Each pipeline gets a fresh environment, ensuring isolation.  
- **Artifacts**: Pipelines can pass files (e.g., compiled binaries) between jobs using the `artifacts` keyword.  

#### **Example**  
```yaml
workflow:
  name: 'Production Deployment Pipeline - $CI_COMMIT_REF_NAME'
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_COMMIT_MESSAGE !~ /skip-ci/
      when: always
    - when: never # Skip all other cases

stages:
  - build
  - deploy

build_job:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

deploy_job:
  stage: deploy
  script:
    - aws s3 cp dist/ s3://prod-bucket/
```

#### **Production Scenario**  
For a cloud storage service like Dropbox:  
- **Trigger**: A push to `main` with a commit message lacking `skip-ci`.  
- **Workflow**: Named "Production Deployment Pipeline - main" in the UI.  
- **Process**:  
  1. `build_job` compiles a TypeScript API into a `dist/` folder and saves it as an artifact.  
  2. `deploy_job` uploads `dist/` to an S3 bucket serving the live API.  
- **Edge Case**: If a hotfix commit includes `[skip-ci]`, the pipeline skips—perfect for documentation-only changes.  
- **Scale**: Multiple pipelines might run concurrently (e.g., for `dev` and `main`), tracked by their unique names.

---

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">🛤️ 2. Stages</span>

#### **Definition**  
Stages are the **ordered milestones** in your pipeline. They group jobs into logical phases (e.g., `build`, `test`, `deploy`), running sequentially while allowing parallelism within each stage.

#### **Deep Dive**  
- **Sequential Execution**: Stages run top-to-bottom as listed in `stages:`. If `test` fails, `deploy` never starts—think of it as a safety net.  
- **Parallelism**: Jobs in the same stage (e.g., `unit_tests` and `integration_tests` in `test`) run concurrently if runners are available.  
- **Definition**: You must explicitly list stages in `.gitlab-ci.yml`. Undefined stages are ignored, and jobs without a `stage` default to `test`.  
- **Dependencies**: The `needs` keyword can override stage order (more on this in DAG pipelines), but by default, stages dictate flow.  
- **Customization**: Add as many stages as needed—`lint`, `security`, `package`, etc.—to mirror your workflow.  
- **Failure Handling**: A single job failure in a stage halts the pipeline unless marked `allow_failure: true`.  

#### **Example**  
```yaml
stages:
  - build
  - test
  - deploy

build_frontend:
  stage: build
  script: npm run build:frontend

build_backend:
  stage: build
  script: npm run build:backend

unit_tests:
  stage: test
  script: npm run test:unit

integration_tests:
  stage: test
  script: npm run test:integration

deploy_prod:
  stage: deploy
  script: docker push my-app:latest
```

#### **Production Scenario**  
For a ride-sharing app like Uber:  
- **Build Stage**:  
  - `build_frontend`: Compiles the React driver app.  
  - `build_backend`: Builds the Go-based dispatch API. Both run in parallel.  
- **Test Stage**:  
  - `unit_tests`: Validates core logic (e.g., fare calculations).  
  - `integration_tests`: Ensures frontend talks to backend. These run simultaneously.  
- **Deploy Stage**:  
  - `deploy_prod`: Pushes a Docker image to a registry for Kubernetes rollout.  
- **Real-World Twist**: If `integration_tests` fail due to a flaky API, the pipeline stops, preventing a broken app from reaching drivers.

---

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">⚙️ 3. Jobs</span>

#### **Definition**  
Jobs are the **atomic tasks** within a pipeline—self-contained units of work executed on runners. They’re the muscle behind each stage.

#### **Deep Dive**  
- **Runners**: Jobs execute on GitLab runners (shared or self-hosted). A runner picks up a job based on availability and matching `tags`.  
- **Tags**: Keywords like `docker`, `gpu`, or `prod` route jobs to specialized runners. No matching runner? The job queues indefinitely.  
- **Structure**:  
  - **`before_script`**: Global or job-specific setup (e.g., install tools). Runs in the same shell as `script`.  
  - **`script`**: The main task. Must be defined—empty scripts fail.  
  - **`after_script`**: Post-task actions (e.g., cleanup). Runs regardless of success, unless the job is manually canceled.  
- **Artifacts**: Use `artifacts:paths` to save files (e.g., test reports) for later jobs or download. Artifacts expire unless preserved via GitLab settings.  
- **Variables**: Jobs inherit pipeline-wide variables (e.g., `$CI_COMMIT_SHA`) or custom ones defined in YAML.  
- **Timeout**: Jobs default to a runner-specific timeout (e.g., 1 hour on shared runners) but can be overridden with `timeout`.  
- **Retry**: Add `retry: 2` to rerun flaky jobs up to two times on failure.  

#### **Example**  
```yaml
build_image:
  stage: build
  tags:
    - docker
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
  script:
    - docker build -t my-app:$CI_COMMIT_SHA .
    - docker push my-app:$CI_COMMIT_SHA
  after_script:
    - docker logout
  artifacts:
    paths:
      - build.log
  retry: 2
```

#### **Production Scenario**  
For a video conferencing app like Zoom:  
- **Job**: `build_image` creates a Docker image for the signaling server.  
- **Tags**: Runs on a `docker`-tagged runner with Docker installed.  
- **Before Script**: Logs into GitLab’s registry using predefined CI variables.  
- **Script**: Builds and pushes the image with the commit SHA as the tag.  
- **After Script**: Logs out to prevent credential leaks.  
- **Artifacts**: Saves a `build.log` for debugging.  
- **Retry**: If the push fails due to a network blip, it retries twice—crucial for unreliable cloud connections.

---

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">📜 4. Scripts</span>

#### **Definition**  
Scripts are the **command sequences** that power jobs—`before_script`, `script`, and `after_script` dictate what happens at each phase.

#### **Deep Dive**  
- **`before_script`**:  
  - Runs first, setting the stage. Often used for dependency installation or environment setup.  
  - Can be global (pipeline-wide) or job-specific. Overriding a global `before_script` requires explicit redefinition.  
  - Fails? The job stops before `script` runs.  
- **`script`**:  
  - The heart of the job—required and must exit with code `0` (success).  
  - Commands run sequentially in a single shell session. A failure (e.g., `exit 1`) halts the job immediately.  
  - Multi-line? Use `-` for readability; each line is a separate command.  
- **`after_script`**:  
  - Runs last, even on `script` failure, unless the job is canceled mid-run.  
  - Ideal for logging, notifications, or cleanup. Exit code doesn’t affect job status.  
- **Shell**: Defaults to `bash` (Linux) or `cmd` (Windows), configurable via runner settings or `.gitlab-ci.yml` (`image` keyword).  
- **Debugging**: Add `set -x` in `script` to trace commands—lifesaver for cryptic failures.  

#### **Example**  
```yaml
deploy_prod:
  stage: deploy
  before_script:
    - apt-get update && apt-get install -y awscli
    - aws configure set region us-west-2
  script:
    - set -x # Debug mode
    - aws s3 sync ./dist s3://prod-bucket --delete
    - curl -X POST -d "Deployed $CI_COMMIT_SHA to prod" $SLACK_WEBHOOK_URL
  after_script:
    - echo "Deployment duration: $((SECONDS)) seconds" >> metrics.log
```

#### **Production Scenario**  
For a news app like CNN’s mobile site:  
- **Before Script**: Installs AWS CLI and sets the region—runs on a fresh runner every time.  
- **Script**: Syncs a built site to S3 ( `--delete` removes stale files) and notifies Slack with the commit SHA. Debug mode (`set -x`) logs each step.  
- **After Script**: Records runtime in `metrics.log` for performance tracking.  
- **Edge Case**: If S3 sync fails (e.g., creds expire), `after_script` still logs the attempt, aiding post-mortems.

---

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">🚀 Pipeline Types with Deep Examples</span>

#### **1. Basic Pipeline**  
- **What**: Linear, stage-driven flow. Simple but rigid.  
- **Example**:  
```yaml
stages: [build, test, deploy]
build_job:
  stage: build
  script: gcc -o app main.c
test_job:
  stage: test
  script: ./app --test
deploy_job:
  stage: deploy
  script: scp app prod-server:/app/
```
- **Production Use**: A legacy C-based CLI tool—builds, tests, and deploys to a bare-metal server.

#### **2. DAG Pipeline**  
- **What**: Dependency-driven (via `needs`), bypassing stage order for speed.  
- **Example**:  
```yaml
build_api:
  script: go build -o api
test_api:
  needs: [build_api]
  script: ./api --test
deploy_api:
  needs: [test_api]
  script: aws lambda update-function-code --function-name api
```
- **Production Use**: A serverless API—`test_api` starts as soon as `build_api` finishes, skipping stage delays.

#### **3. Merge Request Pipeline**  
- **What**: Runs only for MRs, enforcing pre-merge checks.  
- **Example**:  
```yaml
workflow:
  rules:
    - if: $CI_MERGE_REQUEST_ID
      when: always
    - when: never
lint_code:
  script: eslint .
```
- **Production Use**: A banking app—runs ESLint on MRs to catch style issues before merging to `main`.

#### **4. Parent-Child Pipeline**  
- **What**: Modularizes workflows into sub-pipelines.  
- **Example**:  
```yaml
trigger_frontend:
  trigger:
    include: frontend-ci.yml
```
*frontend-ci.yml*:  
```yaml
build_frontend:
  script: npm run build
```
- **Production Use**: A monorepo—triggers a frontend build while backend runs separately.

#### **5. Multi-Project Pipeline**  
- **What**: Links pipelines across repos.  
- **Example**:  
```yaml
trigger_docs:
  trigger:
    project: "org/docs-site"
    branch: main
    strategy: depend # Waits for downstream success
```
- **Production Use**: An e-commerce API—triggers a docs rebuild in `org/docs-site` after deploying.

---

### <span style="font-family: -apple-system, BlinkMacSystemFont; font-weight: 600;">🎯 Key Takeaways</span>  
- **🌐 Pipelines**: Event-driven workflows with fine-grained control.  
- **🛤️ Stages**: Sequential guardrails with parallel power.  
- **⚙️ Jobs**: Isolated, tagged workers with artifacts and retries.  
- **📜 Scripts**: Command-line precision with setup and cleanup.  
- **🚀 Types**: From basic to multi-project, tailored for complexity.  

