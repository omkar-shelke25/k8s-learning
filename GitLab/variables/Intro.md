

# 📝 Deep Notes on GitLab CI/CD Variables

## 1. Overview

GitLab CI/CD variables are key–value pairs that empower your pipelines by:
- **Configuring behavior:** Tailor how jobs run across various environments.
- **Securing sensitive data:** Store API keys, tokens, and credentials outside your source code.
- **Enabling dynamic pipelines:** Change parameters at runtime without editing the YAML file.

They fall into three primary categories:
- **Global (Default) Variables**
- **Job-Level (Local) Variables**
- **Predefined Variables**

(See [GitLab CI/CD variables documentation](citeturn0search0) for more details.)

---

## 2. Types of Variables

### Global Variables
- **Definition:** Declared at the top of your `.gitlab-ci.yml` or set via project settings.
- **Scope:** Available to every job unless overridden.
- **Usage:** Common values like API endpoints, environment names, and default timeouts.
- **Example:**
  ```yaml
  variables:
    GLOBAL_ENV: "production"
    API_ENDPOINT: "https://api.example.com"
    TIMEOUT: "30s"
  ```
- **Best Practice:** Use secure storage (GitLab UI settings) for secrets rather than plain YAML.

### Job-Level Variables
- **Definition:** Defined within a job’s block.
- **Scope:** Limited to that job, with higher precedence over global variables.
- **Usage:** Adjust configurations for testing or deployment.
- **Example:**
  ```yaml
  test_job:
    stage: test
    variables:
      GLOBAL_ENV: "staging"  # Overrides the global "production" value for this job
      TIMEOUT: "60s"         # Custom timeout for testing
    script:
      - echo "Testing in $GLOBAL_ENV with timeout $TIMEOUT"
  ```

### Predefined Variables
- **Definition:** Automatically provided by GitLab during runtime.
- **Scope:** Include context such as pipeline IDs, job IDs, commit SHA, and branch names.
- **Usage:** Use them for logging, debugging, and making decisions dynamically.
- **Example:**
  ```yaml
  build_job:
    stage: build
    script:
      - echo "Job ID: $CI_JOB_ID"
      - echo "Building branch: $CI_COMMIT_REF_NAME"
  ```
- **Note:** Predefined variables are immutable once the job starts.  
  (Refer to the [Predefined CI/CD variables reference](citeturn0search1) for a full list.)

---

## 3. Variable Resolution Order

When GitLab runs your pipeline, it resolves variables in this hierarchy:

1. **Job-Level Variables:** Highest precedence; override any global definitions.
2. **Global Variables:** Serve as default values across all jobs.
3. **Predefined Variables:** Automatically injected and used for runtime context.

*Illustrative Example:*
```yaml
variables:
  ENV: "production"  # Global default

test_job:
  stage: test
  variables:
    ENV: "staging"   # Local override
  script:
    - echo "Running tests in $ENV"  # Outputs: "staging"
```

---

## 4. Best Practices for Production

- **Secure Your Secrets:**  
  - **Recommendation:** Use GitLab’s project or group settings to add protected, masked variables instead of embedding them in `.gitlab-ci.yml`.  
    (See [Security with Sensitive Data](citeturn0search0) for details.)
  
- **Use Clear Naming Conventions:**  
  - **Tip:** Adopt descriptive and consistent naming (e.g., `PROD_API_ENDPOINT`, `STAGING_TIMEOUT`) to avoid confusion.
  
- **Leverage Predefined Variables:**  
  - **Example:** Log `$CI_PIPELINE_ID` and `$CI_JOB_ID` to trace jobs and diagnose issues.
  
- **Test in a Staging Environment:**  
  - **Approach:** Override global variables in job-level definitions for non-production jobs to mimic production behavior safely.
  
- **Document Your Configuration:**  
  - **Practice:** Comment your YAML file to explain why variables are set, especially when overriding defaults.

*Production Pipeline Example:*
```yaml
# Global settings for production
variables:
  ENV: "production"
  API_ENDPOINT: "https://api.example.com"
  TIMEOUT: "30s"

stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo "Building for $ENV using $API_ENDPOINT"
    - echo "Job ID: $CI_JOB_ID"

test_job:
  stage: test
  variables:
    ENV: "staging"      # Test environment override
    TIMEOUT: "60s"      # Extended timeout for tests
  script:
    - echo "Running tests in $ENV with timeout $TIMEOUT"
    - echo "Pipeline ID: $CI_PIPELINE_ID"

deploy_job:
  stage: deploy
  script:
    - echo "Deploying branch $CI_COMMIT_REF_NAME to $ENV"
    - echo "Using API endpoint: $API_ENDPOINT"
```
In this configuration, the **test_job** demonstrates how job-level variables override global settings to simulate a staging environment before production deployment.

---

## 5. Additional Insights and Advanced Use Cases

- **Variable Expansion:**  
  - Use the `$` symbol (or `${}` for clarity) to reference variables. This enables string concatenation and dynamic command construction.
  
- **Passing Variables Across Jobs:**  
  - Artifacts and dotenv reports can pass environment variables from one job to another.
  
- **Debugging Pipelines:**  
  - Enable debug logging (with `CI_DEBUG_TRACE`) to see expanded variables during job execution.
  
- **Dynamic Pipelines:**  
  - Use GitLab’s [rules and workflow](citeturn0search6) to conditionally include or skip jobs based on variable values or changes in code.

---

## References

- **CI/CD Variables Overview:**  
  [GitLab CI/CD Variables](citeturn0search0)
- **Predefined Variables List:**  
  [Predefined CI/CD Variables](citeturn0search1)
- **Getting Started with GitLab CI/CD:**  
  [Get started with GitLab CI/CD](citeturn0search5)

---

