from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import uvicorn
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="User Service",
    description="User management microservice",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class User(BaseModel):
    id: Optional[int] = None
    username: str
    email: str
    full_name: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class HealthResponse(BaseModel):
    status: str
    service: str
    timestamp: datetime
    uptime: float
    environment: str

# In-memory storage (replace with database in production)
users_db = []
user_id_counter = 1

@app.get("/")
def root():
    """Root endpoint"""
    return {
        "service": "User Service",
        "version": "1.0.0",
        "description": "User management microservice",
        "endpoints": {
            "health": "/health",
            "ready": "/ready",
            "users": "/users",
            "docs": "/docs"
        }
    }

@app.get("/health", response_model=HealthResponse)
def health_check():
    """Health check endpoint"""
    import time
    return HealthResponse(
        status="healthy",
        service="user-service",
        timestamp=datetime.now(),
        uptime=time.process_time(),
        environment=os.getenv("ENVIRONMENT", "development")
    )

@app.get("/ready")
def readiness_check():
    """Readiness check endpoint"""
    # Check database connection, dependencies, etc.
    is_ready = True  # Simplified for now
    
    if is_ready:
        return {
            "status": "ready",
            "service": "user-service",
            "timestamp": datetime.now()
        }
    else:
        raise HTTPException(status_code=503, detail="Service not ready")

@app.get("/users", response_model=List[User])
def get_users():
    """Get all users"""
    return users_db

@app.get("/users/{user_id}", response_model=User)
def get_user(user_id: int):
    """Get a specific user by ID"""
    for user in users_db:
        if user.id == user_id:
            return user
    raise HTTPException(status_code=404, detail="User not found")

@app.post("/users", response_model=User, status_code=201)
def create_user(user: User):
    """Create a new user"""
    global user_id_counter
    
    # Check if username or email already exists
    for existing_user in users_db:
        if existing_user.username == user.username:
            raise HTTPException(status_code=400, detail="Username already exists")
        if existing_user.email == user.email:
            raise HTTPException(status_code=400, detail="Email already exists")
    
    # Add user to database
    user.id = user_id_counter
    user.created_at = datetime.now()
    user.updated_at = datetime.now()
    user_id_counter += 1
    users_db.append(user)
    
    return user

@app.put("/users/{user_id}", response_model=User)
def update_user(user_id: int, user_update: User):
    """Update an existing user"""
    for i, user in enumerate(users_db):
        if user.id == user_id:
            user_update.id = user_id
            user_update.created_at = user.created_at
            user_update.updated_at = datetime.now()
            users_db[i] = user_update
            return user_update
    raise HTTPException(status_code=404, detail="User not found")

@app.delete("/users/{user_id}")
def delete_user(user_id: int):
    """Delete a user"""
    for i, user in enumerate(users_db):
        if user.id == user_id:
            del users_db[i]
            return {"message": "User deleted successfully"}
    raise HTTPException(status_code=404, detail="User not found")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        reload=os.getenv("ENVIRONMENT", "development") == "development"
    )