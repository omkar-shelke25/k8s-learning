# 🌟 Deep Dive into GitLab CI/CD Variables

## ✅ Overview of Variables
In **GitLab CI/CD**, variables manage configurations, secrets, and environment settings. They enable pipelines to be **dynamic** and **secure** without hardcoding values.

### 🌐 Types of Variables
1. **Global Variables** - Defined at the pipeline level, applicable to all jobs.
2. **Local (Job-Level) Variables** - Defined within specific jobs, overriding global values.
3. **Predefined Variables** - Automatically injected by GitLab at runtime.

---

## 1️⃣ Global Variables

### 📝 What They Are
- Defined under the `variables:` section in `.gitlab-ci.yml`.
- Available **across all jobs** and **all pipeline stages**.
- Best suited for **API URLs, build configs, shared settings**.

### 📅 Example:
```yaml
variables:
  GLOBAL_ENV: "production"
  API_URL: "https://api.example.com"
```

### 🔧 Best Practices:
- **Centralization** - Define constants once for consistency.
- **Security** - Store sensitive data in **GitLab CI/CD settings** instead of `.gitlab-ci.yml`.
- **Avoid Overwriting** - They are immutable once the pipeline starts.

---

## 2️⃣ Local (Job-Level) Variables

### 📝 What They Are
- Defined inside **individual job blocks**.
- Scope is **limited to that specific job**.
- **Overrides** global variables when declared with the same name.

### 📅 Example:
```yaml
test_job:
  stage: test
  variables:
    GLOBAL_ENV: "staging"  # Overrides global value
  script:
    - echo "Testing in $GLOBAL_ENV"
```

### 🔧 Best Practices:
- **Use for fine-tuning** job-specific configurations.
- **Override only when necessary** to avoid confusion.
- **Keep secure data in GitLab settings** rather than the `.gitlab-ci.yml` file.

---

## 3️⃣ Predefined Variables

### 📝 What They Are
- **Automatically set** by GitLab.
- Provide **pipeline context** (e.g., job ID, branch name, commit details).
- **Immutable** and cannot be overridden.

### 📅 Example:
```yaml
build_job:
  stage: build
  script:
    - echo "Job ID: $CI_JOB_ID"
    - echo "Pipeline ID: $CI_PIPELINE_ID"
    - echo "Branch: $CI_COMMIT_REF_NAME"
```

### 🔧 Best Practices:
- Use predefined variables to **fetch pipeline metadata dynamically**.
- Ideal for **logging, debugging, and deployment strategies**.
- Combine with global/local variables for **better flexibility**.

---

## ♻️ Variable Resolution Order
GitLab resolves variables in this priority:

1. **Job-Level Variables** (🔑 Highest priority)
2. **Global Variables**
3. **Predefined Variables** (🔒 Cannot be overridden)

### 📅 Example:
```yaml
variables:
  ENV: "production"

test_job:
  stage: test
  variables:
    ENV: "staging"  # Overrides global value
  script:
    - echo "Running tests in $ENV"
```

**Result:** `Running tests in staging`

---

## 🚀 Advanced Usage
### ⚙️ Variable Expansion
- **Syntax:** `$VARIABLE_NAME` or `${VARIABLE_NAME}`
- **String Concatenation:**
  ```yaml
  script:
    - echo "Deploying to ${GLOBAL_ENV} using ${API_URL}"
  ```

### 🔒 Handling Secrets
- Store **API keys and passwords** in **GitLab CI/CD settings** under **masked variables**.
- Example usage:
  ```yaml
  script:
    - echo "Authenticating with API key: $SECRET_API_KEY"
  ```

---

## 👩‍🎓 Practical Production Example
```yaml
# Global variables
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
    ENV: "staging"
    TIMEOUT: "60s"
  script:
    - echo "Testing in $ENV with timeout $TIMEOUT"
    - echo "Pipeline ID: $CI_PIPELINE_ID"

deploy_job:
  stage: deploy
  script:
    - echo "Deploying $CI_COMMIT_REF_NAME branch"
    - echo "Timeout: $TIMEOUT"
```

---

## ✨ Best Practices Recap
- **🔐 Store secrets securely** using GitLab CI/CD settings.
- **📅 Use global variables** for consistency, local variables for overrides.
- **👁️ Debug efficiently** using predefined variables.
- **🛠️ Validate changes** in a test environment before deployment.
- **♻️ Use meaningful variable names** for maintainability.

Mastering GitLab CI/CD variables ensures a **secure, efficient, and flexible** pipeline setup for production-ready workflows! ✨
