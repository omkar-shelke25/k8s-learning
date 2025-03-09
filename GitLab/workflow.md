

### **Adding a Workflow to a Pipeline**

The `workflow` keyword is used at the top level of the `.gitlab-ci.yml` file. It uses `rules` to define conditions for pipeline creation.

#### Example: Basic Workflow
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: always
    - if: $CI_COMMIT_BRANCH =~ /feature\/.*/
      when: manual
    - if: $CI_COMMIT_BRANCH == "develop"
      when: delayed
      start_in: 5 minutes
    - when: never
```

#### Explanation:
1. **Always run pipelines for the `main` branch**:
   - If the commit is on the `main` branch, the pipeline will always run.
2. **Manual pipelines for feature branches**:
   - If the branch name matches the regex `/feature\/.*/`, the pipeline will be created but must be triggered manually.
3. **Delayed pipelines for the `develop` branch**:
   - If the commit is on the `develop` branch, the pipeline will start after a 5-minute delay.
4. **Skip pipelines for all other cases**:
   - If none of the above conditions are met, the pipeline will not be created.

---

### **Advanced Workflow Examples**

#### 1. **Run Pipelines Only for Merge Requests**
```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: always
    - when: never
```
- This workflow ensures pipelines only run for Merge Requests (MRs).

---

#### 2. **Skip Pipelines for Specific Branches**
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_REF_NAME == "skip-ci"
      when: never
    - when: always
```
- This skips pipelines for commits on the `skip-ci` branch.

---

#### 3. **Run Pipelines for Tags or Main Branch**
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_TAG
      when: always
    - if: $CI_COMMIT_BRANCH == "main"
      when: always
    - when: never
```
- Pipelines will only run for tags or commits on the `main` branch.

---

#### 4. **Run Pipelines for Specific Commit Messages**
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_MESSAGE =~ /\[skip ci\]/
      when: never
    - when: always
```
- This skips pipelines if the commit message contains `[skip ci]`.

---

#### 5. **Run Pipelines for Specific Users**
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_AUTHOR == "admin@example.com"
      when: always
    - when: never
```
- Pipelines will only run for commits made by `admin@example.com`.

---

### **Combining Workflow with Jobs**
You can combine the `workflow` rules with job-level `rules` to create more granular control over your pipeline.

#### Example:
```yaml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: always
    - if: $CI_COMMIT_BRANCH =~ /feature\/.*/
      when: manual
    - when: never

stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo "Building the application..."
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

test_job:
  stage: test
  script:
    - echo "Running tests..."
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy_job:
  stage: deploy
  script:
    - echo "Deploying to production..."
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

---

### **Key Variables for Workflow Rules**
Here are some commonly used variables in `workflow` rules:
- `$CI_COMMIT_BRANCH`: The branch name.
- `$CI_COMMIT_TAG`: The tag name (if the pipeline is triggered by a tag).
- `$CI_PIPELINE_SOURCE`: The source of the pipeline (e.g., `push`, `merge_request_event`, `schedule`, etc.).
- `$CI_COMMIT_REF_NAME`: The branch or tag name.
- `$CI_COMMIT_MESSAGE`: The commit message.
- `$CI_COMMIT_AUTHOR`: The commit author's email.

---

### **Best Practices for Workflows**
1. Use `workflow` to control pipeline creation at a high level.
2. Use job-level `rules` for finer control over individual jobs.
3. Test your workflow rules thoroughly to avoid skipping necessary pipelines.
4. Document your workflow rules for team clarity.

By adding a `workflow` section to your `.gitlab-ci.yml`, you can ensure pipelines are created only when necessary, saving resources and improving efficiency.
