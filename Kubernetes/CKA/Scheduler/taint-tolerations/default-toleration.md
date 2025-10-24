# 🧠 **When & How Default Tolerations Are Added to Pods**

---

## ⚙️ **1️⃣ The Source — Kubernetes System Default**

Yes ✅ — those two tolerations:

```yaml
- key: "node.kubernetes.io/not-ready"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300

- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
```

are **added automatically by Kubernetes**
to almost every **Pod created via a controller** (like Deployment, ReplicaSet, StatefulSet, DaemonSet, Job, etc.).

---

## 🧩 **2️⃣ Who Adds Them?**

They are not added by you, not even by your YAML —
they’re added by the **Kubernetes control plane**, specifically during Pod creation by the **kube-controller-manager**.

Here’s the internal flow 👇

---

## 🧭 **3️⃣ Creation Flow (Behind the Scenes)**

1. You create a Deployment, ReplicaSet, or Pod YAML (no tolerations).

   ```bash
   kubectl apply -f app.yaml
   ```

2. The **Deployment Controller** (in `kube-controller-manager`)
   creates the actual **Pod object** in the API server.

3. During Pod creation, Kubernetes **injects default tolerations** into the Pod spec —
   these tolerations are hardcoded into the controller logic for fault tolerance.

4. Result:
   If you check the Pod YAML, you’ll see tolerations even if you didn’t add them.

---

## 🔍 **4️⃣ Check It Yourself**

Run this command on any running Pod:

```bash
kubectl get pod <pod-name> -o yaml | grep -A5 tolerations
```

✅ You’ll see:

```yaml
tolerations:
- key: "node.kubernetes.io/not-ready"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
```

Even though your YAML didn’t contain them —
that’s **Kubernetes adding them automatically**.

---

## ⚙️ **5️⃣ Why Kubernetes Adds Them by Default**

Because if these tolerations weren’t present:

* Pods would be **evicted immediately** whenever a node had a short network glitch.
* Even a small connectivity blip (like 10 seconds) could trigger **mass evictions**.
* That would make the cluster unstable.

So Kubernetes gives every Pod a **5-minute grace period** before eviction.
That’s why it adds these tolerations automatically.

---

## 🧩 **6️⃣ Which Pods Get Them Automatically**

| Pod Type                              | Default Tolerations Added? | Notes                                              |
| ------------------------------------- | -------------------------- | -------------------------------------------------- |
| From Deployments / ReplicaSets        | ✅ Yes                      | Automatically added                                |
| From StatefulSets / Jobs / CronJobs   | ✅ Yes                      | Automatically added                                |
| From DaemonSets                       | ✅ Yes                      | Usually also has `operator: Exists` for all taints |
| Static Pods (kubelet-managed)         | ❌ No                       | Not created via controllers                        |
| Manually created Pods (`kubectl run`) | ✅ Yes                      | Injected by API defaults                           |

---

## 🧱 **7️⃣ Where This Is Defined**

The behavior is defined in the **default admission chain** inside `kube-controller-manager`.
You can see it in Kubernetes source code under:

```
pkg/controller/controller_utils.go
```

(Where the default tolerations for node conditions are appended automatically.)

---

## 🧩 **8️⃣ Important: You Can Override or Extend It**

You can **add your own tolerations** in your Pod spec,
and Kubernetes will **merge** them with the defaults.

Example:

```yaml
tolerations:
- key: "gpu"
  operator: "Exists"
  effect: "NoSchedule"
```

Result → your Pod will have:

* Your custom toleration
* Plus the 2 default “node condition” tolerations.

✅ It never removes the system ones unless you explicitly disable admission plugins (which is rare).

---

## 🧭 **9️⃣ Summary Table**

| Concept            | Behavior                                                |
| ------------------ | ------------------------------------------------------- |
| When added         | Automatically during Pod creation                       |
| Who adds them      | Kubernetes `kube-controller-manager` (controller logic) |
| Why added          | To prevent premature eviction on node flaps             |
| How long tolerated | 300 seconds (5 minutes)                                 |
| Can you change?    | Yes — override or add your own tolerations              |
| Applied to         | Most Pods (except static ones)                          |

---

## ✅ **In One Line (CKA Memory Tip)**

> “When a Pod is created, Kubernetes automatically adds default tolerations
> for `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable`
> with 300-second grace — so Pods aren’t evicted too quickly
> if a node goes temporarily offline.”


