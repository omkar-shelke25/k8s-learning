# 🧠 **What Happens to Default Tolerations When You Add Custom Ones?**

---

## ⚙️ 1️⃣ **Default Behavior**

When Kubernetes creates any Pod (via Deployment, Job, etc.),
it automatically adds **two system tolerations**:

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

✅ These are called **default node condition tolerations**.
They’re automatically injected to prevent your Pods from being evicted too quickly when a node temporarily goes offline.

---

## 🧩 2️⃣ **If You Add Your Own Tolerations**

Now, suppose you add your own toleration block in your Pod spec, like this:

```yaml
tolerations:
- key: "gpu"
  operator: "Exists"
  effect: "NoSchedule"
```

Kubernetes will **merge** your tolerations with the defaults.
So the final Pod spec will contain:

```yaml
tolerations:
- key: "gpu"
  operator: "Exists"
  effect: "NoSchedule"
- key: "node.kubernetes.io/not-ready"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
```

✅ **The defaults are NOT removed.**
Kubernetes always appends your custom tolerations to the system ones — it does not replace them.

---

## 🚫 3️⃣ **When Default Tolerations Get Replaced (Rare Case)**

The only time the default tolerations might not appear is:

* You are using a **custom admission controller** or **mutating webhook** that overrides Pod specs.
* You create a **Static Pod** (not managed by controller-manager).
* You disable default admission plugins (not typical in managed clusters).

So normally — **adding new tolerations never removes the defaults.**

---

## 🧭 4️⃣ **Now, Node Becomes Unhealthy**

When your node becomes **Unreachable** or **NotReady**,
these system taints are automatically applied:

```
node.kubernetes.io/not-ready:NoExecute
node.kubernetes.io/unreachable:NoExecute
```

Kubernetes then checks:

> “Does the Pod tolerate these taints?”

✅ If yes → Pod **stays for 300 seconds** (because of `tolerationSeconds: 300`)
❌ If no (rare, custom setup) → Pod **evicted immediately**

---

## 🧩 5️⃣ **So, Your Custom Tolerations Won’t Affect the Default Eviction Logic**

Example:

```yaml
tolerations:
- key: "maintenance"
  operator: "Exists"
  effect: "NoSchedule"
```

Even though you added a `maintenance` toleration,
Kubernetes **still keeps** the system tolerations for
`not-ready` and `unreachable`.

So the Pod **still gets 300s grace** before eviction if the node fails.

✅ Custom tolerations **add more rules**, they don’t **remove defaults**.

---

## ⚙️ 6️⃣ **What If You Want to Control the Eviction Time**

You *can* override the `tolerationSeconds` for those same keys.
For example:

```yaml
tolerations:
- key: "node.kubernetes.io/not-ready"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 600
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 600
```

Now your Pod will **wait 10 minutes** instead of 5 minutes before eviction.
This replaces the **default** values for those keys only.

So:

* Adding **new keys** → Merges with defaults
* Adding **same keys** → Overrides that default toleration

---

## 🧭 7️⃣ **Example Scenario**

### Before:

Pod created → Kubernetes adds default tolerations:

```
not-ready = 300s
unreachable = 300s
```

### You add custom toleration:

```
gpu=true:NoSchedule
```

➡️ Pod now has **3 tolerations** (merged).

### You override system toleration:

```
node.kubernetes.io/not-ready:NoExecute (600s)
```

➡️ Pod now uses **your version (600s)** instead of default 300s.

---

## ✅ 8️⃣ **Final Summary Table**

| Action                             | Result                                           |
| ---------------------------------- | ------------------------------------------------ |
| Add new toleration (different key) | ✅ Merged with defaults                           |
| Add toleration with same key       | 🔁 Replaces default one                          |
| Don’t add anything                 | 🧩 Defaults applied automatically                |
| Node becomes unhealthy             | 🕔 Pod stays 300s (or custom time), then evicted |
| Node recovers early                | 🟢 Pod stays running; no eviction                |

---

## 💬 **In One Line**

> When a Pod is created, Kubernetes automatically adds default tolerations for `NotReady` and `Unreachable` (300s).
>
> If you add your own tolerations, they are **merged** — not removed.
>
> If the node goes unhealthy, the Pod waits (default 5 mins) before eviction and then gets rescheduled on a healthy node.

---

