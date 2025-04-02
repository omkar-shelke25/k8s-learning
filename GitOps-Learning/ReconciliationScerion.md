Here’s a simple example to understand ArgoCD Reconciliation and Webhook Integration in an easy way.


---

Scenario:

You have a Kubernetes application deployed using ArgoCD, and your manifests (YAML files) are stored in a GitHub repository.
Your goal is to automatically sync your cluster with the latest changes in Git as quickly as possible.


---

1. Default ArgoCD Synchronization (Polling Mode)

How It Works:

1. By default, ArgoCD checks the Git repository every 3 to 5 minutes.


2. If it finds any changes, it updates the Kubernetes cluster.


3. This means if you push a change, it could take up to 5 minutes before ArgoCD applies it.



Example:

Suppose your Git repo contains a Kubernetes deployment file:

apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2

You update replicas: 2 → replicas: 4 and push this change to Git.

ArgoCD will poll every 3–5 minutes to detect this update.

The Kubernetes cluster gets updated when ArgoCD finds the change.


Problem:

If you want instant updates, waiting for 3–5 minutes is slow.
To fix this, we configure webhooks.


---

2. Faster Synchronization Using Webhooks (Recommended Method)

How Webhooks Work:

1. Instead of waiting for ArgoCD to poll the Git repository,
GitHub (or another Git provider) will notify ArgoCD instantly when a new push happens.


2. As soon as you push a change to Git, GitHub sends a webhook event to ArgoCD.


3. ArgoCD immediately fetches the update and applies it to Kubernetes.




---

Steps to Set Up Webhook (Example with GitHub)

Step 1: Get Your ArgoCD Webhook URL

Your ArgoCD webhook URL looks like this:

https://<your-argocd-server>/api/webhook

If you installed ArgoCD in a Kubernetes cluster, your ArgoCD server might be accessible at:

https://argocd.example.com/api/webhook


---

Step 2: Add Webhook in GitHub

1. Go to your GitHub repository.


2. Click on Settings → Webhooks.


3. Click Add webhook.


4. In the Payload URL field, enter:

https://argocd.example.com/api/webhook


5. Set Content Type to application/json.


6. Under Which events would you like to trigger this webhook?, select Just the push event.


7. Click Add webhook.




---

Step 3: Test the Webhook

1. Make a small change in your Git repo (e.g., update replicas: 4 → replicas: 6 in deployment.yaml).


2. Commit and push the change to GitHub.


3. GitHub immediately sends a webhook notification to ArgoCD.


4. ArgoCD syncs the change instantly (no waiting for polling).




---

3. Changing the Reconciliation Timeout (Optional Step)

If you still want to change the default polling timeout (in case webhooks aren’t used), follow these steps.

Command to Update Timeout to 5 Minutes (300s)

kubectl patch configmap argocd-cm -n argocd --patch '{"data": {"timeout.reconciliation": "300"}}'

Restart the ArgoCD Repo Server

kubectl rollout restart deployment argocd-repo-server -n argocd

Now, even without webhooks, ArgoCD will check for updates every 5 minutes instead of 3.


---

Summary:

Best Practice:
Use webhooks for real-time updates, and only rely on polling as a backup.

This ensures instant deployments whenever you push code!

