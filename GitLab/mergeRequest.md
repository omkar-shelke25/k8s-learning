## 1. Overview

### What It Means:
A CI/CD pipeline automates the process of building, testing, and deploying code. However, not every job (task) in the pipeline should run for every code change. For instance, some jobs—like deploying a preview environment—are only relevant when a developer creates a *merge request* (a request to merge code from one branch to another), not for every random commit or push to the main branch. The transcript explains how to configure this selective behavior using a YAML file (a common format for CI/CD configurations).

### Deep Explanation:
In a production environment, running every job for every commit can waste time and resources. Imagine you have a pipeline with 10 jobs: compiling code, running tests, building a Docker image, and deploying a preview. If a developer pushes a small typo fix directly to the main branch, you probably don’t need to deploy a preview—that’s overkill. Instead, you can configure the pipeline to detect *why* it’s running (e.g., a merge request vs. a push) and only trigger specific jobs when they’re needed.

### Example:
Suppose you’re working on a web app. Your pipeline has:
- A `build` job (runs every time).
- A `deploy_preview` job (only for merge requests).
Using a YAML file, you’ll define rules to control when `deploy_preview` runs, ensuring it skips regular commits.

---

## 2. Pre-Defined Variables in CI/CD

### What They Are:
Pre-defined variables are pieces of information automatically provided by the CI/CD system (e.g., GitLab, Jenkins) about the pipeline’s context. They act like built-in labels telling you what’s happening—think of them as the “who, what, where” of the pipeline.

### Deep Explanation:
These variables are set without you needing to define them manually. They’re super useful for decision-making in your pipeline. For example:
- **Who triggered it?** A developer pushing code or a merge request?
- **What branch?** Main or a feature branch?
- **What commit?** The exact code change being processed.

One key variable is `$CI_PIPELINE_SOURCE`, which tells you the event that started the pipeline. Possible values include:
- `push`: Someone pushed code to a branch.
- `merge_request_event`: A merge request was created or updated.
- `web`: Someone manually started the pipeline via the UI.

### Example:
Imagine you’re managing a repo for an e-commerce site. You push a bug fix to the `main` branch—`$CI_PIPELINE_SOURCE` becomes `push`. Later, you create a merge request to add a new checkout feature—`$CI_PIPELINE_SOURCE` switches to `merge_request_event`. Your pipeline can use this variable to decide what to do.

### Production Use:
In a real app, you might use `$CI_MERGE_REQUEST_IID` (a merge request ID) to label a preview deployment like `preview-mr-42`. This variable only exists during merge requests, so you can limit preview jobs to those events.

---

## 3. The `rules` Keyword

### What It Does:
The `rules` keyword in your YAML file lets you decide whether a job runs based on conditions—like a gatekeeper for your pipeline. It’s how you say, “Only run this job if X is true.”

### Deep Explanation:
`rules` is an array (a list) of conditions. Each condition checks something (e.g., a variable’s value) and decides if the job should be included or skipped. Key parts:
- **`if`:** Tests a condition, like `$CI_PIPELINE_SOURCE == "merge_request_event"`.
- **`when`:** Defines what happens if the condition is true (e.g., `always` to run the job) or false (e.g., `never` to skip it).
- **`changes`:** Checks if specific files changed (not covered here, but useful for context).

Rules are evaluated in order, and the first matching rule decides the job’s fate. If no rule matches, the job might not run at all (depending on the CI/CD system).

### Example:
Here’s a job that only runs for merge requests:

```yaml
deploy_preview:
  script:
    - echo "Deploying preview for merge request..."
    - ./deploy_preview.sh
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

- **Line-by-Line:**
  - `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'`: Checks if the pipeline was triggered by a merge request.
  - `when: always`: If true, the job runs.
  - `when: never`: If the `if` condition fails (e.g., it’s a push), the job is skipped.

### Production Scenario:
You’re building a mobile app. The `deploy_preview` job uploads a test version to a server for reviewers to try. You don’t want this running for every commit—just merge requests. The rule ensures it only triggers when a developer submits a merge request, saving server resources.

---

## 4. How Merge Request–Specific Jobs Work

### What It Means:
Some jobs rely on data (like merge request variables) that only exist when a merge request triggers the pipeline. You use rules to make sure these jobs don’t run otherwise.

### Deep Explanation:
When a pipeline starts, the CI/CD system checks the trigger event. For a merge request, it sets variables like `$CI_MERGE_REQUEST_SOURCE_BRANCH` (the branch being merged) and `$CI_MERGE_REQUEST_TARGET_BRANCH` (the destination, e.g., `main`). These aren’t available for a regular push. Rules let you tie jobs to these events:
- **Evaluation:** Rules are checked immediately when the pipeline is created.
- **Outcome:** If the condition matches (e.g., merge request), the job runs; if not, it’s excluded.

### Example:
```yaml
print_mr_details:
  script:
    - echo "Merge request from $CI_MERGE_REQUEST_SOURCE_BRANCH to $CI_MERGE_REQUEST_TARGET_BRANCH"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

- **Behavior:**
  - Merge request created: Prints branch details (e.g., `feature-one` to `main`).
  - Direct push to `main`: Skipped because `$CI_PIPELINE_SOURCE` isn’t `merge_request_event`.

### Production Use Case:
For a game app, you might have a job that builds a demo version for QA to test during merge requests. It uses `$CI_MERGE_REQUEST_IID` to tag the build (e.g., `demo-mr-15`). Rules ensure this only happens for merge requests, not random commits.

---

## 5. Step-by-Step Production Example

### Deep Walkthrough:
Let’s simulate a real-world scenario for a blog platform.

#### Step 1: Create a Feature Branch
- You create a branch called `add-comments` to add a comment feature.
- You edit `comments.py` and commit: `git commit -m "Add comment system"`.

#### Step 2: Define a Merge Request–Only Job
- Your `.gitlab-ci.yml` looks like this:
  ```yaml
  build:
    script:
      - echo "Building the app..."
      - ./build.sh

  deploy_preview:
    script:
      - echo "Deploying preview for MR #$CI_MERGE_REQUEST_IID"
      - ./deploy_preview.sh
    rules:
      - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
        when: always
      - when: never
  ```
  - `build` runs every time; `deploy_preview` waits for a merge request.

#### Step 3: Create a Merge Request
- Push the branch: `git push origin add-comments`.
- In GitLab, create a merge request:
  - **Title:** “Add comment system”
  - **Description:** “New feature for user comments.”
  - **Assignee:** Yourself (for review).
  - **Labels:** “feature,” “testing.”
- This triggers a pipeline with `$CI_PIPELINE_SOURCE = "merge_request_event"`.

#### Step 4: Pipeline Behavior
- **Direct Push to `main`:** If you’d pushed to `main`, only `build` runs. `deploy_preview` is skipped (`when: never` applies).
- **Merge Request:** Both jobs run:
  - `build`: “Building the app...”
  - `deploy_preview`: “Deploying preview for MR #7” (assuming it’s merge request #7).

#### Step 5: Validate the Pipeline
- Check the pipeline logs in GitLab’s UI. You’ll see:
  - Merge request details (e.g., `add-comments` → `main`).
  - Job status: `build` (success), `deploy_preview` (success).
- Use GitLab’s pipeline editor to test the YAML syntax.

---

## 6. Additional Concepts and Best Practices

### Multiple Rules:
You can stack rules for complex logic:
```yaml
test_job:
  script:
    - echo "Running tests..."
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: always
    - when: never
```
- Runs for merge requests *or* pushes to `main`.

### Debugging:
If `deploy_preview` doesn’t run:
- Check `$CI_PIPELINE_SOURCE` in logs (e.g., add `echo $CI_PIPELINE_SOURCE` to a script).
- Ensure the `if` condition matches the variable’s value exactly.

### Documentation:
For GitLab, see:
- [Predefined Variables](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html).
- [Rules Docs](https://docs.gitlab.com/ee/ci/yaml/#rules).

### Production Benefits:
- **Efficiency:** Skip unnecessary jobs.
- **Feedback:** Faster testing for merge requests.
- **Security:** Isolate sensitive jobs (e.g., deployments) to specific events.

---

## 7. Summary

### Core Idea:
Use `$CI_PIPELINE_SOURCE` and `rules` to make jobs run only for merge requests, optimizing your CI/CD pipeline.

### Key Takeaways:
- **Variables:** `$CI_PIPELINE_SOURCE` tells you the trigger.
- **Rules:** Control job execution with `if` and `when`.
- **Example:** Deploy previews only for merge requests, not every push.
