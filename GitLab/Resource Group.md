
## Understanding Pipelines and Concurrency in GitLab CI/CD

Before we explore resource groups, let’s establish some foundational concepts about GitLab CI/CD pipelines.

### What is a Pipeline?
A **pipeline** in GitLab CI/CD is a collection of **jobs** that are executed in **stages**. These jobs are defined in a configuration file called `.gitlab-ci.yml`, typically located in the root of your project repository. A pipeline is triggered by an event, such as:
- A commit to a branch (e.g., `main`).
- A merge request.
- A manual trigger via the GitLab UI.

Each pipeline runs independently and progresses through its stages (e.g., `build`, `test`, `deploy`). By default, multiple pipelines can run **concurrently** if multiple triggers occur simultaneously. For example:
- If you push three commits to the `main` branch in quick succession, three pipelines might start running at the same time.

### Jobs and Concurrency
A **job** is a single task within a pipeline, such as compiling code, running tests, or deploying an application. Jobs within the same stage of a single pipeline can run in parallel if configured to do so, but jobs across different pipelines are independent unless controlled otherwise.

#### Example of Concurrent Pipelines
Imagine a simple `.gitlab-ci.yml`:
```yaml
stages:
  - build
  - deploy

build_job:
  stage: build
  script:
    - echo "Building the app..."

deploy_job:
  stage: deploy
  script:
    - echo "Deploying to production..."
```
- **Commit 1**: Triggers Pipeline 1 (build_job → deploy_job).
- **Commit 2**: Triggers Pipeline 2 (build_job → deploy_job).
- **Commit 3**: Triggers Pipeline 3 (build_job → deploy_job).

Without any restrictions, all three pipelines could run their `deploy_job`s at the same time. This concurrency is fine for tasks like building or testing, but it can cause issues in certain scenarios, such as deployments.

### The Problem with Concurrent Deployments
In deployment scenarios, running multiple jobs concurrently can lead to conflicts. For example:
- If `deploy_job` updates a production server, two simultaneous deployments might overwrite each other’s changes or leave the server in an inconsistent state.
- Example: Pipeline 1’s `deploy_job` is halfway through updating files when Pipeline 2’s `deploy_job` starts, causing a race condition.

To avoid this, you might want deployment jobs to run **one by one** (serially) rather than concurrently. This is where **resource groups** come into play.

---

## What Are Resource Groups?

**Resource groups** in GitLab CI/CD are a mechanism to ensure that certain jobs are **mutually exclusive** across different pipelines within the same project. They act like a lock (or mutex) that prevents multiple jobs assigned to the same resource group from running at the same time. If multiple jobs tied to the same resource group are triggered, only one runs, and the others wait until the resource group is free.

### Key Purpose
- **Control concurrency**: Ensure that critical jobs (e.g., deployments) don’t overlap, avoiding conflicts or race conditions.
- **Scope**: Resource groups apply across all pipelines for the **same project**. They don’t affect jobs in different projects.

### How to Define a Resource Group
You assign a resource group to a job in the `.gitlab-ci.yml` file using the `resource_group` keyword. The value is a string that identifies the group (e.g., `"production"`, `"staging"`, or any custom name).

#### Example Configuration
```yaml
deploy_job:
  stage: deploy
  script:
    - echo "Deploying to production..."
    - sleep 300  # Simulate a 5-minute deployment
  resource_group: production
```
Here, the `deploy_job` belongs to the `"production"` resource group. Only one job with the `resource_group: production` can run at a time across all pipelines in the project.

---

## How Resource Groups Work: A Practical Example

Let’s walk through an example to see resource groups in action.

### Scenario
- You have a project with the `.gitlab-ci.yml` above.
- You push a commit to the `main` branch, triggering **Pipeline 1**.
- While Pipeline 1’s `deploy_job` is running (for 5 minutes due to `sleep 300`), you manually schedule another pipeline (**Pipeline 2**) for the same branch.

### Step-by-Step Execution
1. **Pipeline 1 Starts**:
   - `build_job` runs and completes.
   - `deploy_job` starts and occupies the `"production"` resource group. It will run for 5 minutes.

2. **Pipeline 2 is Triggered**:
   - `build_job` runs and completes (no resource group, so it’s unaffected).
   - `deploy_job` tries to start but sees that the `"production"` resource group is in use by Pipeline 1’s `deploy_job`.
   - Pipeline 2’s `deploy_job` enters a **waiting state**, with a message like: *"This job is waiting for resource 'production'."*

3. **Resolution**:
   - After 5 minutes, Pipeline 1’s `deploy_job` completes, freeing the `"production"` resource group.
   - Pipeline 2’s `deploy_job` immediately starts running.

4. **Manual Intervention**:
   - Alternatively, if you cancel Pipeline 1’s `deploy_job` before it finishes (via the GitLab UI), the resource group is freed instantly, and Pipeline 2’s `deploy_job` starts right away.

### Visualization
| Time       | Pipeline 1         | Pipeline 2         |
|------------|--------------------|--------------------|
| 0:00       | `deploy_job` starts| -                  |
| 0:01       | Running            | Triggered, waiting |
| 2:00       | Cancelled          | `deploy_job` starts|
| 5:00       | -                  | Completes          |

This demonstrates how resource groups serialize job execution, ensuring only one `deploy_job` runs at a time.

---

## Process Modes: Controlling the Order of Waiting Jobs

When multiple jobs in the same resource group are queued, GitLab uses a **process mode** to determine the order in which they run. There are three modes:
1. **Unordered** (default)
2. **Oldest First**
3. **Newest First**

### 1. Unordered Mode
- **Behavior**: Jobs waiting for the resource group run in an unpredictable order. Any queued job can start next when the resource group is free.
- **Example**:
  - Three commits trigger Pipeline 1 (`deploy1`), Pipeline 2 (`deploy2`), and Pipeline 3 (`deploy3`).
  - `deploy1` starts first and takes 5 minutes.
  - `deploy2` and `deploy3` wait.
  - After `deploy1` finishes, either `deploy2` or `deploy3` could run next (e.g., order might be `deploy1` → `deploy3` → `deploy2`).

### 2. Oldest First Mode
- **Behavior**: Jobs run in the order they were triggered (first in, first out).
- **Example**:
  - `deploy1` (triggered at 0:00) starts.
  - `deploy2` (0:01) and `deploy3` (0:02) wait.
  - Order: `deploy1` → `deploy2` → `deploy3`.

### 3. Newest First Mode
- **Behavior**: Jobs run in reverse order of when they were triggered (last in, first out).
- **Example**:
  - `deploy1` (0:00) starts.
  - `deploy2` (0:01) and `deploy3` (0:02) wait.
  - Order: `deploy1` → `deploy3` → `deploy2`.

### Changing the Process Mode
- The default is **unordered**.
- To switch to `oldest_first` or `newest_first`, you must use the **GitLab CI REST API**. This isn’t configurable directly in `.gitlab-ci.yml` (as of now, based on standard GitLab documentation).
- Example API call (conceptual):
  ```
  PUT /api/v4/projects/:id/resource_groups/production
  {
    "process_mode": "oldest_first"
  }
  ```

---

## Multiple Resource Groups in a Project

You can define multiple resource groups within a project to manage different sets of jobs independently.

### Example with Staging and Production
```yaml
deploy_to_staging:
  stage: deploy
  script:
    - echo "Deploying to staging..."
  resource_group: staging

deploy_to_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
  resource_group: production
```
- **Behavior**:
  - `deploy_to_staging` jobs are serialized among themselves (only one can run at a time).
  - `deploy_to_production` jobs are serialized among themselves.
  - A `deploy_to_staging` and a `deploy_to_production` can run **concurrently** because they belong to different resource groups.

#### Scenario
- Pipeline 1: `deploy_to_staging` (uses `"staging"`) and `deploy_to_production` (uses `"production"`) → Both run together.
- Pipeline 2: Another `deploy_to_staging` → Waits until Pipeline 1’s `deploy_to_staging` finishes, but `deploy_to_production` in Pipeline 1 is unaffected.

---

## Deep Notes with Example

Let’s tie everything together with a comprehensive example.

### `.gitlab-ci.yml`
```yaml
stages:
  - build
  - deploy

build_job:
  stage: build
  script:
    - echo "Building..."

deploy_job:
  stage: deploy
  script:
    - echo "Starting deployment..."
    - sleep 300  # 5 minutes
    - echo "Deployment done."
  resource_group: production
```

### Sequence of Events
1. **Commit 1** (Pipeline 1):
   - `build_job` → Completes.
   - `deploy_job` → Starts, locks `"production"`.

2. **Commit 2** (Pipeline 2):
   - `build_job` → Completes.
   - `deploy_job` → Waits (unordered mode).

3. **Commit 3** (Pipeline 3):
   - `build_job` → Completes.
   - `deploy_job` → Waits.

4. **After 5 Minutes**:
   - Pipeline 1’s `deploy_job` finishes.
   - Either Pipeline 2 or 3’s `deploy_job` starts next (unordered).

5. **Cancel Demo**:
   - If you cancel Pipeline 1’s `deploy_job` after 2 minutes, Pipeline 2 or 3’s `deploy_job` starts immediately.

### Key Takeaways
- **Concurrency Control**: Only one `deploy_job` runs at a time due to the `"production"` resource group.
- **Waiting State**: Jobs show a clear status in the GitLab UI (e.g., "waiting for resource 'production'").
- **Flexibility**: You can use different resource groups for different purposes (e.g., `"staging"`, `"production"`) within the same project.

---

## Additional Notes
- **Project-Specific**: Resource groups are scoped to a single project. Jobs in different projects don’t share resource groups, even if the names match.
- **REST API Limitation**: Changing process modes via API might be intentional to prevent frequent configuration changes in `.gitlab-ci.yml`, but it’s less convenient for users.
- **Documentation**: For more details, refer to the GitLab CI/CD YAML syntax reference under “resource_group” (available in GitLab’s official docs).

---


