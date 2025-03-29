If you use an anchor (&name) and reference it (<<: *name) without overriding any keys, it will work exactly as defined in the anchor. The referenced content will be copied as-is into the job.

Example (Without Overriding)

.common_settings: &common_settings
  image: bitnami/kubectl:1.23
  before_script:
    - echo "Setting up environment"

deploy_job:
  <<: *common_settings
  stage: deploy
  script:
    - kubectl apply -f deployment.yaml

What Happens?

deploy_job inherits everything from common_settings without any modifications.

The image and before_script remain unchanged.



---

If You Don't Override a Key That Exists in the Anchor

If the anchor has a before_script, but you don't override it in the job, the original before_script remains the same.

Example

.deploy_base: &deploy_base
  image: bitnami/kubectl:1.23
  before_script:
    - echo "Preparing deployment"
  dependencies:
    - docker_push

dev_deploy:
  <<: *deploy_base
  stage: deploy
  script:
    - kubectl apply -f dev.yaml

What Happens?

The before_script (echo "Preparing deployment") remains unchanged because it was not overridden.

dependencies are inherited as well.


If You Override a Key

If you override a key (e.g., before_script), it replaces the one from the anchor.

Example (Overriding before_script)

dev_deploy:
  <<: *deploy_base
  stage: deploy
  before_script:
    - echo "Using a different setup for dev"
  script:
    - kubectl apply -f dev.yaml

What Happens?

The new before_script replaces the one from the anchor (echo "Using a different setup for dev").

Other values (image, dependencies) stay the same.



---

Summary

Would you like a deeper explanation of how this works under the YAML specification?

