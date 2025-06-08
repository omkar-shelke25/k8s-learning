#!/bin/bash

# Predefined MongoDB password
MONGO_PASSWORD="microPass123"

# Create directory for Kubernetes manifests
mkdir -p k8s-manifests
cd k8s-manifests

echo "🔧 Generating Kubernetes manifests for microservices setup..."

# 1. Namespace
cat <<EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
EOF

# 2. MongoDB Secret
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

# 3. MongoDB Community CR
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
            resources:
              requests:
                storage: 1Gi
EOF

# 4. User Service
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
          image: omkara25/simple-microservice-app-user-service
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

# 5. Order Service
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
          image: omkara25/simple-microservice-app-order-service
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

# 6. Payment Service
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
          image: omkara25/simple-microservice-app-payment-service
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

echo "✅ All manifests generated successfully in ./k8s-manifests"
echo "📂 You can apply them using: kubectl apply -f ./k8s-manifests"
