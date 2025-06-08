#!/bin/bash

set -e

# MongoDB password
MONGO_PASSWORD="microPass123"

# Create directory for manifests
mkdir -p k8s-manifests
cd k8s-manifests

echo "🔧 Step 1: Installing MongoDB Kubernetes Operator..."

# Create namespace if not exists
kubectl get ns mongodb >/dev/null 2>&1 || kubectl create namespace mongodb

# Install MongoDB Operator
kubectl apply -k "https://github.com/mongodb/mongodb-kubernetes-operator/config/crd?ref=v0.7.6"
kubectl apply -k "https://github.com/mongodb/mongodb-kubernetes-operator/config/rbac?ref=v0.7.6"
kubectl apply -k "https://github.com/mongodb/mongodb-kubernetes-operator/config/manager?ref=v0.7.6"

# Wait for operator pod to be ready
echo "⏳ Waiting for MongoDB Operator to be ready..."
kubectl wait --for=condition=Available=True deployment/mongodb-kubernetes-operator -n mongodb --timeout=60s

# Install local-path provisioner if not present
if ! kubectl get sc | grep -q 'local-path'; then
  echo "📦 Installing local-path provisioner..."
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
fi

echo "✅ MongoDB Operator and local-path provisioner set up."

echo "🔧 Step 2: Generating Kubernetes manifests..."

# 1. Namespace
cat <<EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
EOF

# 2. Persistent Volume (500Mi using local-path)
cat <<EOF > mongodb-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
  namespace: microservices
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  hostPath:
    path: "/mnt/data/mongodb"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: microservices
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 500Mi
EOF

# 3. MongoDB user password secret
cat <<EOF > mongodb-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-user-password
  namespace: microservices
type: Opaque
stringData:
  password: $MONGO_PASSWORD
EOF

# 4. MongoDB Community Custom Resource
cat <<EOF > mongodb.yaml
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb
  namespace: microservices
spec:
  members: 1
  type: ReplicaSet
  version: "7.0.0"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: micro_user
      db: user_db
      passwordSecretRef:
        name: mongodb-user-password
      roles:
        - db: user_db
          role: readWrite
  statefulSet:
    spec:
      volumeClaimTemplates:
        - metadata:
            name: data-volume
          spec:
            accessModes: [ "ReadWriteOnce" ]
            storageClassName: local-path
            resources:
              requests:
                storage: 500Mi
EOF

# 5. User Service
cat <<EOF > user-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
        - name: user-service
          image: omkara25/simple-microservice-app-user-service:v1
          ports:
            - containerPort: 8001
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:$MONGO_PASSWORD@mongodb-svc.microservices.svc.cluster.local:27017/user_db"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  selector:
    app: user-service
  ports:
    - port: 8001
      targetPort: 8001
EOF

# 6. Order Service
cat <<EOF > order-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
        - name: order-service
          image: omkara25/simple-microservice-app-order-service:v1
          ports:
            - containerPort: 8002
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:$MONGO_PASSWORD@mongodb-svc.microservices.svc.cluster.local:27017/order_db"
            - name: USER_SERVICE_URL
              value: "http://user-service:8001"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: microservices
spec:
  selector:
    app: order-service
  ports:
    - port: 8002
      targetPort: 8002
EOF

# 7. Payment Service
cat <<EOF > payment-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
        - name: payment-service
          image: omkara25/simple-microservice-app-payment-service:v1
          ports:
            - containerPort: 8003
          env:
            - name: MONGODB_URI
              value: "mongodb://micro_user:$MONGO_PASSWORD@mongodb-svc.microservices.svc.cluster.local:27017/payment_db"
            - name: ORDER_SERVICE_URL
              value: "http://order-service:8002"
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: microservices
spec:
  selector:
    app: payment-service
  ports:
    - port: 8003
      targetPort: 8003
EOF

echo "✅ YAML files generated in ./k8s-manifests"
echo "📦 To apply them: kubectl apply -f ./k8s-manifests"
