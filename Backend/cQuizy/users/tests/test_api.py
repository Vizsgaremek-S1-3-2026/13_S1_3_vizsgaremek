# users/tests/test_api.py
#TODO: pytest users/tests/ -v --reuse-db -p no:warnings

import pytest
from django.contrib.auth import get_user_model

User = get_user_model()

# Tell pytest this entire file needs database access
pytestmark = pytest.mark.django_db

def test_hello_endpoint(client):
    """Test the basic unauthenticated /hello endpoint."""
    response = client.get("/hello")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, your API works!"}

def test_register_user_success(client):
    """Test successful user registration."""
    payload = {
        "username": "new_user",
        "email": "new@example.com",
        "password": "securepassword",
        "first_name": "john",
        "last_name": "doe",
        "nickname": "Johnny"
    }
    
    response = client.post("/register", json=payload)
    
    assert response.status_code == 200
    assert "success" in response.json()
    
    #? Felhasználó létrejött-e
    user = User.objects.get(username="new_user")
    assert user.email == "new@example.com"

    #? Név helyesen lett-e formázva
    assert user.first_name == "John" 

def test_login_success(client, test_user):
    """Test login with correct credentials returns a token."""
    payload = {
        "username": "testuser_123",
        "password": "strongpassword123"
    }
    
    response = client.post("/login", json=payload)
    
    assert response.status_code == 200

    #? Token létrejött-e
    assert "token" in response.json()

def test_get_me_authenticated(client, auth_headers, test_user):
    """Test getting current user data with a valid JWT token."""
    response = client.get("/me", headers=auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == test_user.username
    assert data["email"] == test_user.email

def test_get_me_unauthenticated(client):
    """Test getting current user data fails without a token."""
    response = client.get("/me")
    
    assert response.status_code == 401 

def test_delete_account(client, auth_headers, test_user):
    """Test soft-deletion of the user account."""
    payload = {
        "password": "strongpassword123"
    }
    
    response = client.delete("/me", json=payload, headers=auth_headers)
    
    assert response.status_code == 200
    
    # Felhasználó újratöltése, létezik e még
    test_user.refresh_from_db()
    
    assert test_user.is_active is False
    assert test_user.date_deleted is not None
    #? E-mail anonymizálva lett-e
    assert test_user.email != "test@email.com"