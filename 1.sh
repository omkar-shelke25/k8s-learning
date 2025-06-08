#!/bin/bash

# Create directories
mkdir -p ~/Simple-Microservice-App/{user-service,order-service,payment-service,k8s}

# Create k8s manifests
cat > ~/Simple-Microservice-App/k8s/configmaps.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-service-config
  namespace: default
data:
  PORT: "8001"
  MONGODB_URI: "mongodb://my-mongodb-0.my-mongodb-svc.default.svc.cluster.local:27017/user_db"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-service-config
  namespace: default
data:
  PORT: "8002"
  MONGODB_URI: "mongodb://my-mongodb-0.my-mongodb-svc.default.svc.cluster.local:27017/order_db"
  USER_SERVICE_URL: "http://user-service.default.svc.cluster.local:8001"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: default
data:
  PORT: "8003"
  MONGODB_URI: "mongodb://my-mongodb-0.my-mongodb-svc.default.svc.cluster.local:27017/payment_db"
  ORDER_SERVICE_URL: "http://order-service.default.svc.cluster.local:8002"
EOF

cat > ~/Simple-Microservice-App/k8s/deployments.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: default
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
        image: user-service:latest
        ports:
        - containerPort: 8001
        envFrom:
        - configMapRef:
            name: user-service-config

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: default
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
        image: order-service:latest
        ports:
        - containerPort: 8002
        envFrom:
        - configMapRef:
            name: order-service-config

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: default
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
        image: payment-service:latest
        ports:
        - containerPort: 8003
        envFrom:
        - configMapRef:
            name: payment-service-config
EOF

cat > ~/Simple-Microservice-App/k8s/services.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: default
spec:
  selector:
    app: user-service
  ports:
  - protocol: TCP
    port: 8001
    targetPort: 8001
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: default
spec:
  selector:
    app: order-service
  ports:
  - protocol: TCP
    port: 8002
    targetPort: 8002
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: default
spec:
  selector:
    app: payment-service
  ports:
  - protocol: TCP
    port: 8003
    targetPort: 8003
  type: ClusterIP
EOF

cat > ~/Simple-Microservice-App/k8s/mongodb-crd.yaml << 'EOF'
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: my-mongodb
  namespace: default
spec:
  members: 3
  type: ReplicaSet
  version: "7.0.2"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
  - name: admin
    db: admin
    passwordSecretRef:
      name: mongodb-admin-password
    roles:
    - name: clusterAdmin
      db: admin
    - name: userAdminAnyDatabase
      db: admin
  additionalMongodConfig:
    storage:
      dbPath: /data/db
EOF

cat > ~/Simple-Microservice-App/k8s/mongodb-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-admin-password
  namespace: default
type: Opaque
data:
  password: YWRtaW5wYXNzd29yZA==  # Base64-encoded "adminpassword"
EOF

# Create User Service files
cat > ~/Simple-Microservice-App/user-service/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
import os

app = FastAPI()

# MongoDB connection
client = MongoClient(os.getenv("MONGODB_URI"))
db = client.get_database()
users_collection = db.users

# Pydantic models
class User(BaseModel):
    name: str
    email: str

class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None

# Routes
@app.post("/users/", response_model=dict)
async def create_user(user: User):
    try:
        user_dict = user.dict()
        result = users_collection.insert_one(user_dict)
        user_dict["_id"] = str(result.inserted_id)  # Convert ObjectId to string
        return user_dict
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/users/{user_id}", response_model=dict)
async def get_user(user_id: str):
    try:
        user = users_collection.find_one({"_id": user_id})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user["_id"] = str(user["_id"])  # Convert ObjectId to string
        return user
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/users/", response_model=list[dict])
async def list_users():
    try:
        users = list(users_collection.find())
        for user in users:
            user["_id"] = str(user["_id"])  # Convert ObjectId to string
        return users
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/users/{user_id}", response_model=dict)
async def update_user(user_id: str, user_update: UserUpdate):
    try:
        update_dict = {k: v for k, v in user_update.dict().items() if v is not None}
        if not update_dict:
            raise HTTPException(status_code=400, detail="No fields to update")
        result = users_collection.update_one({"_id": user_id}, {"$set": update_dict})
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        user = users_collection.find_one({"_id": user_id})
        user["_id"] = str(user["_id"])  # Convert ObjectId to string
        return user
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/users/{user_id}", response_model=dict)
async def delete_user(user_id: str):
    try:
        result = users_collection.delete_one({"_id": user_id})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="User not found")
        return {"message": "User deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health", response_model=dict)
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)
EOF

cat > ~/Simple-Microservice-App/user-service/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn==0.32.0
pymongo==4.10.1
httpx==0.27.2
EOF

cat > ~/Simple-Microservice-App/user-service/Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8001
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

# Create Order Service files
cat > ~/Simple-Microservice-App/order-service/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
import os
import httpx

app = FastAPI()

# MongoDB connection
client = MongoClient(os.getenv("MONGODB_URI"))
db = client.get_database()
orders_collection = db.orders

# Pydantic models
class Order(BaseModel):
    user_id: str
    product: str
    amount: float

class OrderUpdate(BaseModel):
    product: str | None = None
    amount: float | None = None

# Routes
@app.post("/orders/", response_model=dict)
async def create_order(order: Order):
    try:
        # Verify user exists by calling User Service
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{os.getenv('USER_SERVICE_URL')}/users/{order.user_id}")
            if response.status_code != 200:
                raise HTTPException(status_code=404, detail="User not found")
        
        order_dict = order.dict()
        result = orders_collection.insert_one(order_dict)
        order_dict["_id"] = str(result.inserted_id)  # Convert ObjectId to string
        return order_dict
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/orders/{order_id}", response_model=dict)
async def get_order(order_id: str):
    try:
        order = orders_collection.find_one({"_id": order_id})
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Fetch user details from User Service
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{os.getenv('USER_SERVICE_URL')}/users/{order.user_id}")
            if response.status_code != 200:
                raise HTTPException(status_code=404, detail="User not found")
            user = response.json()
        
        order["_id"] = str(order["_id"])  # Convert ObjectId to string
        return {"order": order, "user": user}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/orders/", response_model=list[dict])
async def list_orders():
    try:
        orders = list(orders_collection.find())
        for order in orders:
            order["_id"] = str(order["_id"])  # Convert ObjectId to string
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/orders/{order_id}", response_model=dict)
async def update_order(order_id: str, order_update: OrderUpdate):
    try:
        update_dict = {k: v for k, v in order_update.dict().items() if v is not None}
        if not update_dict:
            raise HTTPException(status_code=400, detail="No fields to update")
        result = orders_collection.update_one({"_id": order_id}, {"$set": update_dict})
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Order not found")
        order = orders_collection.find_one({"_id": order_id})
        order["_id"] = str(order["_id"])  # Convert ObjectId to string
        return order
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/orders/{order_id}", response_model=dict)
async def delete_order(order_id: str):
    try:
        result = orders_collection.delete_one({"_id": order_id}})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Order not found")
        return {"message": "Order deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health", response_model=dict)
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8002))
    uvicorn.run(app, host="0.0.0.0", port=port)
EOF

cat > ~/Simple-Microservice-App/order-service/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn==0.32.0
pymongo==4.10.1
httpx==0.27.2
EOF

cat > ~/Simple-Microservice-App/order-service/Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8002
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002"]
EOF

# Create Payment Service files
cat > ~/Simple-Microservice-App/payment-service/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
import os
import httpx

app = FastAPI()

# MongoDB connection
client = MongoClient(os.getenv("MONGODB_URI"))
db = client.get_database()
payments_collection = db.payments

# Pydantic models
class Payment(BaseModel):
    order_id: str
    amount: float
    status: str  # e.g., "pending", "completed", "failed"

class PaymentUpdate(BaseModel):
    status: str | None = None
    amount: float | None = None

# Routes
@app.post("/payments/", response_model=dict)
async def create_payment(payment: Payment):
    try:
        # Verify order exists by calling Order Service
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{os.getenv('ORDER_SERVICE_URL')}/orders/{payment.order_id}")
            if response.status_code != 200:
                raise HTTPException(status_code=404, detail="Order not found")
        
        payment_dict = payment.dict()
        result = payments_collection.insert_one(payment_dict)
        payment_dict["_id"] = str(result.inserted_id)  # Convert ObjectId to string
        return payment_dict
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/payments/{payment_id}", response_model=dict)
async def get_payment(payment_id: str):
    try:
        payment = payments_collection.find_one({"_id": payment_id})
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        # Fetch order details from Order Service
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{os.getenv('ORDER_SERVICE_URL')}/orders/{payment.order_id}")
            if response.status_code != 200:
                raise HTTPException(status_code=404, detail="Order not found")
            order = response.json()
        
        payment["_id"] = str(payment["_id"])  # Convert ObjectId to string
        return {"payment": payment, "order": order}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/payments/", response_model=list[dict])
async def list_payments():
    try:
        payments = list(payments_collection.find())
        for payment in payments:
            payment["_id"] = str(payment["_id"])  # Convert ObjectId to string
        return payments
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/payments/{payment_id}", response_model=dict)
async def update_payment(payment_id: str, payment_update: PaymentUpdate):
    try:
        update_dict = {k: v for k, v in payment_update.dict().items() if v is not None}
        if not update_dict:
            raise HTTPException(status_code=400, detail="No fields to update")
        result = payments_collection.update_one({"_id": payment_id}, {"$set": update_dict})
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Payment not found")
        payment = payments_collection.find_one({"_id": payment_id})
        payment["_id"] = str(payment["_id"])  # Convert ObjectId to string
        return payment
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/payments/{payment_id}", response_model=dict)
async def delete_payment(payment_id: str):
    try:
        result = payments_collection.delete_one({"_id": payment_id})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Payment not found")
        return {"message": "Payment deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health", response_model=dict)
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8003))
    uvicorn.run(app, host="0.0.0.0", port=port)
EOF

cat > ~/Simple-Microservice-App/payment-service/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn==0.32.0
pymongo==4.10.1
httpx==0.27.2
EOF

cat > ~/Simple-Microservice-App/payment-service/Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8003
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]
EOF

echo "Project structure created in ~/Simple-Microservice-App"
