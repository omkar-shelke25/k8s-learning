GitLab CI/CD: YAML Anchors (<<), extends, and !reference Deep Dive

1. Introduction

GitLab CI/CD allows job configuration reuse to reduce duplication, improve maintainability, and enforce consistency. This is done using three primary mechanisms:

YAML Anchors (<<): A YAML-native feature to define reusable sections.

extends: A GitLab-specific inheritance mechanism for jobs.

!reference: A GitLab-specific way to selectively reuse specific job attributes.


This guide explores each method in depth, including their differences, use cases, syntax, and behavior.


---

2. YAML Anchors (<<)

Definition

YAML anchors (&) and aliases (*) are pure YAML features that allow you to define and reuse content within a single .gitlab-ci.yml file.

Syntax

.common_config: &common
  image: ubuntu:latest
  before_script:
    - echo "Setting up"
  services:
    - docker:dind

job_1:
  <<: *common  # Merging the common config
  script:
    - echo "Job 1 Running"

job_2:
  <<: *common  # Merging the common config
  script:
    - echo "Job 2 Running"

Key Behaviors

Works only within a single .gitlab-ci.yml file.

Merges entire hash (<<: *anchor), completely overwriting keys when redefined.

Cannot append arrays (e.g., before_script, script). Instead, the new value replaces the anchor's value.

Cannot reference across multiple included files.

Best suited for reusing small, frequently repeated configurations (e.g., image, services).


Applicable Jobs

Anchors can be applied at:

Job Level (to reuse an entire job’s configuration)

Keyword Level (to reuse specific fields like services, before_script).


Pros & Cons


---

3. extends (GitLab-Specific Inheritance)

Definition

GitLab provides extends, a built-in way to inherit from another job. This allows GitLab-specific merging rules, unlike YAML anchors.

Syntax

.common_job:
  image: ubuntu:latest
  before_script:
    - echo "Preparing job"

job_A:
  extends: .common_job  # Inherits everything
  script:
    - echo "Running job A"

job_B:
  extends: .common_job
  script:
    - echo "Running job B"

Key Behaviors

Works across multiple files when using include.

GitLab-specific merging behavior:

Lists (before_script, script) are appended, not replaced.

Hash values (e.g., image, variables) are overridden.


Cannot selectively inherit fields (unlike !reference).

Best suited for enforcing standard structures across multiple jobs.


Applicable Jobs

Any job in GitLab CI/CD, including build, test, deploy, and cleanup jobs.

Works well for defining base templates.


Pros & Cons


---

4. !reference (GitLab-Specific Field-Level Reuse)

Definition

!reference allows selectively inheriting specific fields from another job, making it more flexible than both anchors and extends.

Syntax

.base_job:
  image: ubuntu:latest
  before_script:
    - echo "Preparing"
  script:
    - echo "Base script"

custom_job:
  script:
    - echo "Custom script"
  <<: !reference [.base_job, image, before_script]  # Selectively reuse `image` and `before_script`

Key Behaviors

Works only in GitLab CI/CD (not a YAML feature).

Allows referencing only specific attributes of another job.

Does not merge like extends, instead it picks specific fields.

Great for flexible job configuration without full inheritance.


Applicable Jobs

Any job that needs to inherit only part of another job’s settings.

Works well when you need fine-grained control over reuse.


Pros & Cons


---

5. Summary Table: << vs. extends vs. !reference


---

6. When to Use What?


---

7. Conclusion

By understanding anchors (<<), extends, and !reference, you can optimize your GitLab CI/CD pipelines for efficiency, maintainability, and flexibility. Each method has its own strengths, and the best choice depends on your use case.

Would you like practical examples combining all three methods?

