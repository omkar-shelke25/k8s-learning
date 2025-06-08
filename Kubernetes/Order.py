from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient
from dotenv import load_dotenv
import os
import httpx

load_dotenv()

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
        result = orders_collection.delete_one({"_id": order_id})
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
