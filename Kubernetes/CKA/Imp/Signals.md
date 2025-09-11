

📝 Deep Notes on Kubernetes Termination, Signals, and Sidecars


---

1. Signals in Linux

Signal = a message from the OS to a process.

Common signals used by Kubernetes:

SIGTERM (15) → “Please stop gracefully.”

Can be caught by the process.

Allows cleanup: flush buffers, close files, save state.

Exit codes: usually 0 (clean exit) or 143 (terminated via SIGTERM).


SIGKILL (9) → “Stop now, no excuses.”

Cannot be caught or ignored.

Immediate removal from memory, no cleanup.

Exit code: 137 (128 + 9).





---

2. Kubernetes Pod Termination Flow

1. Pod is deleted (e.g., kubectl delete pod, rolling update, node drain).


2. Kubelet sends SIGTERM to all containers.


3. Pod enters “Terminating” state.


4. Containers have up to terminationGracePeriodSeconds (default: 30s) to stop.


5. During this period:

Probes stop.

Pod readiness goes false.

Traffic is drained from Service/Endpoint.



6. If containers don’t exit in time → kubelet sends SIGKILL.




---

3. Graceful Termination (Grace Period)

Defined with:

spec:
  terminationGracePeriodSeconds: <time>

Default = 30 seconds.

Purpose:

Allow apps to finish work before shutdown.

Prevent data corruption and incomplete transactions.


Behavior:

If container exits early → Pod terminates immediately.

If not → force kill after grace period.



Analogy: Librarian says “10 minutes left” (SIGTERM + grace period). If you don’t leave, security shuts down lights (SIGKILL).


---

4. Sidecar Containers in Kubernetes (v1.29+)

Traditionally: sidecars defined in spec.containers.

Since v1.29:

Sidecars can be written as initContainers with restartPolicy: Always.

Lifecycle:

Start before main containers.

Run alongside main containers.

Terminate only after main containers exit.



Termination behavior:

Sidecars often get less/no grace time because main containers consume the period.

Sidecars may exit with 137 (killed) or 143 (terminated).

This is expected → external tooling should ignore non-zero exit codes for sidecars.




---

5. Importance of SIGTERM for Stateful Apps (Databases)

For database Pods (PostgreSQL, MySQL, MongoDB, etc.):

SIGTERM allows the DB to:

Flush writes to disk.

Close transactions.

Update WAL/journals for crash recovery.

Close network connections.


Prevents:

Data corruption.

Transaction loss.

Slow restart/recovery.


Without SIGTERM (only SIGKILL):

DB is force stopped.

May need recovery on restart.

Risk of data loss.



✅ For databases: always configure longer terminationGracePeriodSeconds (e.g., 60s or more).


---

6. Sidecars vs Databases: Why Different?

Main container (DB/app)

SIGTERM is critical → protects data consistency.


Sidecar container (log shipper, proxy, metrics agent)

Graceful termination less important.

Losing some logs or metrics at shutdown = acceptable.

Kubernetes prioritizes main containers for grace time.




---

7. Exit Codes Recap

0 → Clean exit (success).

143 → Process got SIGTERM and shut down.

137 → Process got SIGKILL (force kill).


👉 In logs, sidecars often show 137 at shutdown — this is normal.


---

8. Real Example (PostgreSQL Deployment)

apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
spec:
  replicas: 1
  template:
    spec:
      terminationGracePeriodSeconds: 60   # allow DB time to shut down safely
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: db-storage
      volumes:
      - name: db-storage
        persistentVolumeClaim:
          claimName: postgres-pvc

When Pod terminates:

PostgreSQL gets SIGTERM → cleans up.

If not done in 60s → SIGKILL is sent.




---

9. Key Takeaways

SIGTERM = graceful stop, allows cleanup.

SIGKILL = force stop, no cleanup.

Grace period = time between SIGTERM and SIGKILL.

Databases → SIGTERM is crucial for preventing data loss.

Sidecars → often don’t get grace time, so their non-zero exit codes should be ignored.



---

✅ Final Summary in One Line
In Kubernetes, SIGTERM + grace period protects critical data apps (like databases) from corruption, while sidecars may be killed abruptly since their role is supportive, not stateful.


---

