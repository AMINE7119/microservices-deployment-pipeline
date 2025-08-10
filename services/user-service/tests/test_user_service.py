import pytest
from fastapi.testclient import TestClient
import sys
import os

# Add the parent directory to the path so we can import the app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app

client = TestClient(app)

class TestUserService:
    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "user-service"
        assert "timestamp" in data

    def test_ready_endpoint(self):
        """Test ready check endpoint"""
        response = client.get("/ready")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert data["service"] == "user-service"

    def test_create_user_success(self):
        """Test creating a user successfully"""
        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User"
        }
        response = client.post("/users/", json=user_data)
        assert response.status_code == 201
        data = response.json()
        assert data["username"] == user_data["username"]
        assert data["email"] == user_data["email"]
        assert data["full_name"] == user_data["full_name"]
        assert "id" in data
        assert "created_at" in data

    def test_create_user_missing_fields(self):
        """Test creating a user with missing required fields"""
        user_data = {
            "username": "testuser"
            # Missing email and full_name
        }
        response = client.post("/users/", json=user_data)
        assert response.status_code == 422
        data = response.json()
        assert "detail" in data

    def test_create_user_invalid_email(self):
        """Test creating a user with invalid email"""
        user_data = {
            "username": "testuser",
            "email": "invalid-email",
            "full_name": "Test User"
        }
        response = client.post("/users/", json=user_data)
        assert response.status_code in [400, 422]  # Both are valid for validation errors

    def test_get_users_empty_list(self):
        """Test getting users returns a list"""
        response = client.get("/users/")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_user_not_found(self):
        """Test getting a non-existent user"""
        response = client.get("/users/99999")
        assert response.status_code == 404
        data = response.json()
        assert data["detail"] == "User not found"

    def test_user_crud_flow(self):
        """Test complete CRUD flow for a user"""
        # Create user
        user_data = {
            "username": "cruduser",
            "email": "crud@example.com", 
            "full_name": "CRUD User"
        }
        create_response = client.post("/users/", json=user_data)
        assert create_response.status_code == 201
        created_user = create_response.json()
        user_id = created_user["id"]
        
        # Get user
        get_response = client.get(f"/users/{user_id}")
        assert get_response.status_code == 200
        fetched_user = get_response.json()
        assert fetched_user["username"] == user_data["username"]
        
        # Update user
        update_data = {
            "username": "updateduser",
            "email": "updated@example.com",
            "full_name": "Updated User"
        }
        update_response = client.put(f"/users/{user_id}", json=update_data)
        assert update_response.status_code == 200
        updated_user = update_response.json()
        assert updated_user["username"] == update_data["username"]
        assert updated_user["email"] == update_data["email"]
        
        # Delete user
        delete_response = client.delete(f"/users/{user_id}")
        assert delete_response.status_code in [200, 204]  # Both are valid for successful delete
        
        # Verify user is deleted
        get_deleted_response = client.get(f"/users/{user_id}")
        assert get_deleted_response.status_code == 404