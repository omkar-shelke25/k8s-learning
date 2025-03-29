Understanding GitLab CI/CD's !reference Tag: Deep Explanation & Examples

GitLab CI/CD offers various methods to optimize pipeline configurations and reduce duplication. Among these methods, the !reference tag enables granular inheritance of configuration elements. This guide provides an in-depth explanation of !reference, its use cases, and comparisons with other GitLab CI/CD features.

What is !reference in GitLab CI/CD?

The !reference tag allows selective inheritance of specific attributes from another job, unlike extends, which copies the entire job. This enables modular and reusable pipeline configurations while avoiding redundancy.

Key Benefits:

Selective Inheritance: Inherit only specific attributes from another job.

Cross-File References: Unlike YAML anchors, !reference works across multiple files when using include.

Enhanced Modularity: Facilitates better organization of pipeline configurations.

Reduced Duplication: Eliminates the need to copy and paste common configuration elements.


Syntax and Usage

The !reference tag follows this format:

job_name:
  some_key: !reference [referenced_job, key_to_copy]

referenced_job: The job you want to reference.

key_to_copy: The specific key to inherit (e.g., before_script, script, image).


Example: Inheriting a Single Key

base_job:
  before_script:
    - echo "Setting up environment"
  script:
    - echo "Running base job"

test_job:
  script:
    - npm test
  before_script: !reference [base_job, before_script]

✅ test_job copies only before_script from base_job, keeping its own script independent.

!reference vs Other Reuse Mechanisms

!reference vs extends

!reference vs YAML Anchors

Advanced Usage Examples

Referencing Multiple Keys

base_job:
  before_script:
    - echo "Preparing environment"
  after_script:
    - echo "Cleanup"

test_job:
  before_script: !reference [base_job, before_script]
  after_script: !reference [base_job, after_script]
  script:
    - echo "Running tests"

✅ test_job inherits before_script and after_script but keeps its own script.

Chained References

job1:
  before_script:
    - echo "Setup job1"

job2:
  before_script: !reference [job1, before_script]
  script:
    - echo "Running job2"

job3:
  before_script: !reference [job2, before_script]
  script:
    - echo "Running job3"

✅ job3 inherits before_script from job2, which in turn inherits from job1.

Combining !reference with extends

.base_template:
  before_script:
    - echo "Base setup"
  script:
    - echo "Base script"

.test_template:
  extends: .base_template
  script:
    - echo "Running tests"

deploy_job:
  extends: .test_template
  before_script: !reference [.base_template, before_script]
  script:
    - echo "Deploying app"

✅ deploy_job extends .test_template but explicitly copies before_script from .base_template.

Best Practices and Considerations

When to Use !reference

For selective inheritance: When only specific parts of a job should be reused.

To improve modularity: When breaking down configurations into reusable components.

For cross-file references: When jobs defined in different include files need to share configurations.


Limitations

Complete replacement: !reference does not merge lists but replaces them.

Order matters: If the same key is declared multiple times, the last occurrence takes precedence.

Not for runtime changes: !reference is resolved at configuration processing time, not during execution.


Conclusion

The !reference tag is a powerful tool for optimizing GitLab CI/CD configurations. By allowing fine-grained inheritance, it enhances modularity and maintainability while avoiding duplication. When combined with extends, it offers a flexible and efficient way to manage complex pipelines.

By understanding its behavior and best practices, teams can create scalable and DRY CI/CD workflows that are easier to maintain and extend.
