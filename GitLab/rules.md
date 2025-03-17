

### The Code Snippet:
Here’s the snippet we’re analyzing, which you’d typically find inside a job definition in a `.gitlab-ci.yml` file:

```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    when: always
  - when: never
```

This is part of a job like this:
```yaml
deploy_preview:
  script:
    - echo "Deploying preview for merge request..."
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

Now, let’s break down each line.

---

### 1. `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'`

#### What It Means:
This line checks a condition: it asks the CI/CD system, “Was this pipeline triggered by a merge request?” It does this by comparing the value of the pre-defined variable `$CI_PIPELINE_SOURCE` to the string `"merge_request_event"`.

#### Deep Explanation:
- **`$CI_PIPELINE_SOURCE`:** This is a variable automatically set by the CI/CD system (e.g., GitLab) when a pipeline starts. It tells you *why* the pipeline is running. Possible values include:
  - `"push"`: Someone pushed code to a branch.
  - `"merge_request_event"`: A merge request was created, updated, or reopened.
  - `"web"`: Someone manually triggered the pipeline via the UI.
  - Others like `"schedule"` or `"api"` (depending on the system).
- **`"merge_request_event"`:** This specific value means the pipeline was triggered because of a merge request action (e.g., creating a merge request from `feature-branch` to `main`).
- **`==`:** This is a comparison operator checking for equality. The `$` tells the system to substitute the variable’s actual value.
- **Quotes (`''`):** In YAML, variables in `if` statements are often enclosed in single quotes to ensure proper string evaluation, avoiding syntax errors.

When this condition is evaluated:
- If `$CI_PIPELINE_SOURCE` equals `"merge_request_event"`, the condition is **true**.
- If it’s anything else (e.g., `"push"`), the condition is **false**.

#### How It Works in the Pipeline:
- The CI/CD system evaluates this `if` statement as soon as the pipeline is created.
- It’s like a filter: only pipelines triggered by merge requests pass this test.

#### Example:
Imagine you’re working on a photo-sharing app:
- **Scenario 1: Push to a Branch**
  - You push a commit to `feature/add-filters`.
  - The pipeline starts, and `$CI_PIPELINE_SOURCE` is set to `"push"`.
  - The condition `$CI_PIPELINE_SOURCE == "merge_request_event"` is **false** because `"push"` ≠ `"merge_request_event"`.
- **Scenario 2: Create a Merge Request**
  - You create a merge request from `feature/add-filters` to `main`.
  - The pipeline starts, and `$CI_PIPELINE_SOURCE` is set to `"merge_request_event"`.
  - The condition is **true** because `"merge_request_event" == "merge_request_event"`.

#### Production Use:
In a real app, you might use this to deploy a preview environment only for merge requests. For example, a job might spin up a temporary server (e.g., `preview-mr-23`) to let reviewers test the new photo filters before merging.

---

### 2. `when: always`

#### What It Means:
If the `if` condition above is **true** (i.e., the pipeline is a merge request event), this line says, “Run the job no matter what.” It’s an instruction to include the job in the pipeline.

#### Deep Explanation:
- **`when`:** This keyword defines the job’s behavior after the `if` condition is checked. It’s like the “what to do next” part of the rule.
- **`always`:** This specific value means “execute the job unconditionally” (assuming the `if` is true). It’s a way to say, “If we’ve made it this far, go ahead and run it.”
- **Context:** `when: always` is paired with the `if` statement above it. If the `if` condition passes, this line ensures the job isn’t skipped or delayed—it runs immediately as part of the pipeline.

Other possible `when` values (for reference):
- `never`: Don’t run the job.
- `manual`: Run only if manually triggered by a user.
- `delayed`: Run after a delay (e.g., `when: delayed` with a `start_in` time).

#### How It Works in the Pipeline:
- If `$CI_PIPELINE_SOURCE == "merge_request_event"` is true, the job (e.g., `deploy_preview`) is added to the pipeline and executed.
- Without this line, the job might not run even if the condition is true (depending on default behavior in some systems), so `when: always` makes it explicit.

#### Example:
Continuing the photo-sharing app:
- **Merge Request Created:**
  - Pipeline starts with `$CI_PIPELINE_SOURCE = "merge_request_event"`.
  - `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` is true.
  - `when: always` kicks in, so the `deploy_preview` job runs, outputting: `"Deploying preview for merge request..."`.
- **Outcome:** A preview site (e.g., `https://preview-mr-23.example.com`) goes live for testing the new filters.

#### Production Use:
In a team setting, this ensures that critical merge request tasks—like deploying a testable version of a feature—happen automatically. For instance, a manager can review the preview without extra steps.

---

### 3. `when: never`

#### What It Means:
If the `if` condition above is **false** (e.g., the pipeline wasn’t triggered by a merge request), this line says, “Don’t run the job—exclude it entirely from the pipeline.”

#### Deep Explanation:
- **`when: never`:** This is a standalone rule (not tied to an `if`) that acts as a fallback. It means “skip the job” if no previous rule in the `rules` array applies.
- **Order Matters:** In a `rules` array, the CI/CD system evaluates rules top-to-bottom:
  - If the first rule (`if: '$CI_PIPELINE_SOURCE == "merge_request_event"'`) is true, it stops there and uses `when: always`.
  - If the first rule is false, it moves to the next rule—here, `when: never`—and applies it.
- **Result:** When this rule triggers, the job is completely omitted from the pipeline. It won’t even show up as “skipped” in some systems—it’s as if it doesn’t exist for that run.

#### How It Works in the Pipeline:
- If `$CI_PIPELINE_SOURCE` is anything other than `"merge_request_event"` (e.g., `"push"`, `"web"`), the first rule fails, and this second rule takes over, excluding the job.

#### Example:
Back to the photo-sharing app:
- **Push to a Branch:**
  - You push a commit to `feature/add-filters`.
  - Pipeline starts with `$CI_PIPELINE_SOURCE = "push"`.
  - `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` is false (`"push"` ≠ `"merge_request_event"`).
  - The pipeline moves to `when: never`, so `deploy_preview` is skipped entirely.
- **Outcome:** No preview site is deployed—saves resources since it’s not a merge request yet.

#### Production Use:
In a busy repo, developers might push dozens of commits daily. Without `when: never`, the `deploy_preview` job could run unnecessarily, clogging servers or wasting cloud credits. This line ensures it only runs when intended.

---

### Putting It All Together

#### Full Flow:
- **Merge Request Case:**
  - Trigger: You create a merge request.
  - `$CI_PIPELINE_SOURCE = "merge_request_event"`.
  - Rule 1: `if` is true → `when: always` → Job runs.
- **Non-Merge Request Case:**
  - Trigger: You push to a branch.
  - `$CI_PIPELINE_SOURCE = "push"`.
  - Rule 1: `if` is false → Rule 2: `when: never` → Job skipped.

#### Complete Example:
```yaml
deploy_preview:
  script:
    - echo "Deploying preview for MR #$CI_MERGE_REQUEST_IID"
    - ./deploy_preview.sh
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

- **Push to `feature/add-filters`:**
  - `$CI_PIPELINE_SOURCE = "push"`.
  - `if` fails → `when: never` → No output, no deployment.
- **Merge Request from `feature/add-filters` to `main`:**
  - `$CI_PIPELINE_SOURCE = "merge_request_event"`.
  - `$CI_MERGE_REQUEST_IID = "23"`.
  - `if` succeeds → `when: always` → Outputs: `"Deploying preview for MR #23"`, then runs `deploy_preview.sh`.

#### Production Scenario:
For a shopping app, this setup ensures:
- Pushes to feature branches (e.g., `add-cart`) don’t waste time deploying previews.
- Merge requests (e.g., `add-cart` → `main`) deploy a testable version (e.g., `preview-mr-45`) for stakeholders to review.

---

### Why This Matters in Production
- **Efficiency:** Prevents unnecessary job runs, saving compute resources.
- **Clarity:** Team knows previews are tied to merge requests, not random commits.
- **Control:** Fine-tunes pipeline behavior for specific workflows.

