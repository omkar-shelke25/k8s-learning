# Common Kubernetes Commands Used in Production

## General Cluster Management

### Switching Namespaces
```bash
kubectl config set-context --current --namespace=<namespace-name>
```

### Viewing Current Namespace
```bash
kubectl config view --minify | grep namespace:
```

### Listing All Namespaces
```bash
kubectl get namespaces
```

---

## Pod Management

### Listing Pods
```bash
kubectl get pods -n <namespace-name>
```

### Describing a Pod
```bash
kubectl describe pod <pod-name> -n <namespace-name>
```

### Viewing Pod Logs
```bash
kubectl logs <pod-name> -n <namespace-name>
```

#### Viewing Logs from a Specific Container in a Pod
```bash
kubectl logs <pod-name> -c <container-name> -n <namespace-name>
```

### Executing Commands in a Pod Container
```bash
kubectl exec -it <pod-name> -c <container-name> -n <namespace-name> -- <command>
```

---

## Deployment Management

### Listing Deployments
```bash
kubectl get deployments -n <namespace-name>
```

### Describing a Deployment
```bash
kubectl describe deployment <deployment-name> -n <namespace-name>
```

### Scaling a Deployment
```bash
kubectl scale deployment <deployment-name> --replicas=<number-of-replicas> -n <namespace-name>
```

### Updating a Deployment Image
```bash
kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n <namespace-name>
```

---

## Service and Network Management

### Listing Services
```bash
kubectl get services -n <namespace-name>
```

### Describing a Service
```bash
kubectl describe service <service-name> -n <namespace-name>
```

### Port Forwarding
```bash
kubectl port-forward <pod-name> <local-port>:<remote-port> -n <namespace-name>
```

---

## ConfigMap and Secret Management

### Listing ConfigMaps
```bash
kubectl get configmaps -n <namespace-name>
```

### Describing a ConfigMap
```bash
kubectl describe configmap <configmap-name> -n <namespace-name>
```

### Listing Secrets
```bash
kubectl get secrets -n <namespace-name>
```

### Describing a Secret
```bash
kubectl describe secret <secret-name> -n <namespace-name>
```

---

## Node and Cluster Information

### Listing Nodes
```bash
kubectl get nodes
```

### Describing a Node
```bash
kubectl describe node <node-name>
```

### Viewing Cluster Info
```bash
kubectl cluster-info
```

---

## Troubleshooting

### Debugging a Pod
```bash
kubectl exec -it <pod-name> -n <namespace-name> -- /bin/sh
```

### Viewing Events
```bash
kubectl get events -n <namespace-name>
```

### Checking Resource Usage
```bash
kubectl top pod -n <namespace-name>
```

### Checking Node Resource Usage
```bash
kubectl top node
```

---

## YAML File Management

### Applying a YAML Configuration
```bash
kubectl apply -f <file-name>.yaml
```

### Deleting Resources from a YAML File
```bash
kubectl delete -f <file-name>.yaml
```

### Dry Run to Test Changes
```bash
kubectl apply -f <file-name>.yaml --dry-run=client
```

---

## Miscellaneous

### Viewing Resource Details in YAML/JSON Format
```bash
kubectl get <resource-type> <resource-name> -n <namespace-name> -o yaml
kubectl get <resource-type> <resource-name> -n <namespace-name> -o json
```

### Deleting a Resource
```bash
kubectl delete <resource-type> <resource-name> -n <namespace-name>
```

### Auto-Complete for Kubectl
```bash
source <(kubectl completion bash)  # For Bash
source <(kubectl completion zsh)  # For Zsh
```

---

This list covers the most commonly used Kubernetes commands in production environments for managing namespaces, pods, deployments, services, nodes, and troubleshooting. Customize the commands as per your cluster's requirements.
