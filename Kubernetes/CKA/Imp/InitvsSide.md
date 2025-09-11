📝 Deep Notes: Init Containers vs Sidecar Containers in Kubernetes


---

🔹 1. Init Containers

Definition:
Init containers are special containers in a Pod that always run before the main application containers start.

Key characteristics:

Run sequentially (one after another, in the order defined).

Each must finish successfully (exit 0) before the next starts.

When all init containers finish, the main app containers are started.

Init containers never restart once complete (unless the whole Pod restarts).

No probes (liveness/readiness/startup) → not needed, since they run only once.

Communication:

Can’t talk directly to main containers (because those aren’t running yet).

Can pass data to main containers using shared volumes (e.g., emptyDir, configMap).



Typical use cases:

Waiting for a service dependency (e.g., database readiness).

Downloading config files before app starts.

Database migration jobs.

Setting permissions on mounted volumes.


Example:

initContainers:
- name: init-db
  image: busybox
  command: ['sh', '-c', 'until nc -z mydb 5432; do echo waiting for db; sleep 2; done']

👉 This ensures the database is ready before the main app runs.


---

🔹 2. Sidecar Containers

Definition:
Sidecar containers are containers that run alongside the main application containers inside the same Pod, providing extra functionality.

Key characteristics:

Run concurrently with the main app.

Active for the entire lifecycle of the Pod.

Can be started and stopped independently of the main container.

Support liveness, readiness, startup probes → lifecycle is managed.

Can interact directly with main containers (same network namespace, can share volumes).

Since v1.29: can be defined as initContainers with restartPolicy: Always, which makes them behave as “true sidecars.”

Changing a sidecar’s image causes only that container to restart, not the whole Pod.


Typical use cases:

Logging (e.g., Fluentd, Logstash).

Monitoring agents (Prometheus exporters).

Proxies (Envoy, Istio sidecars).

Data synchronization tools.


Example:

initContainers:
- name: log-shipper
  image: alpine
  restartPolicy: Always
  command: ["sh", "-c", "tail -F /var/log/app.log"]

👉 This sidecar collects logs while the main app runs.


---

🔹 3. Major Differences Between Init & Sidecar Containers

Feature	Init Container	Sidecar Container

Start time	Always before main containers	Starts before/with main containers
Run duration	Runs once → exits	Runs for entire Pod lifecycle
Execution order	Sequential, one after another	Concurrent with main containers
Dependency	Must complete before app starts	Independent but supportive of app
Probes	❌ Not supported	✅ Supported
Communication	Cannot talk to app (not started)	Can talk directly (shared net/volumes)
Restart behavior	Doesn’t restart unless Pod restarts	Can restart independently
Use cases	Setup, dependency checks, initialization	Logging, monitoring, proxying, extending functionality



---

🔹 4. Lifecycle Visualization

Init Containers:

[Init 1] ---> [Init 2] ---> [Init 3] ---> [Main Containers Start]

Each must finish before the next starts.

Once done, they never run again unless Pod restarts.


Sidecar Containers:

[Sidecar(s)] <-----> [Main Container(s)]
(run together for entire Pod life)

Work alongside the app, providing services in real time.



---

🔹 5. Why the Difference Matters

Init containers are about preparation.

Example: prepare DB schema, fetch secrets, warm caches.


Sidecars are about extension.

Example: ship logs, route traffic, monitor health.



👉 If init containers fail → Pod never runs.
👉 If sidecars fail → Pod may run, but without added features (like logging).


---

🔹 6. Analogy

Init container = a worker who sets up a stage before the play starts. Leaves before actors arrive.

Sidecar container = a stagehand who stays during the play, helping actors with lights, props, and sound effects.



---

🔹 7. Kubernetes v1.29 Update (Sidecar GA)

Sidecars now officially supported as initContainers with restartPolicy: Always.

Clear semantics:

Start before main containers.

Stay running alongside them.

Shut down after main containers stop.


Advantage: lifecycle ordering + automatic cleanup.



---

✅ Final Summary

Init containers run before the app → prepare the environment, then exit.

Sidecar containers run with the app → extend its functionality until the Pod ends.

Init = setup phase.

Sidecar = support role throughout Pod’s life.



