import pytest
from ninja.testing import TestClient
from django.contrib.auth import get_user_model
from users.api import router
from users.auth import generate_token

User = get_user_model()

@pytest.fixture
def client():
    """Returns a Django Ninja TestClient for the users router."""
    return TestClient(router)

@pytest.fixture
def test_user(db):
    """Creates and returns a standard test user."""
    return User.objects.create_user(
        username="testuser_123",
        email="test@email.com",
        password="strongpassword123",
        first_name="Test",
        last_name="User"
    )

@pytest.fixture
def auth_headers(test_user):
    """Generates a real JWT token for the test_user to test secured endpoints."""
    token = generate_token(test_user)
    return {"Authorization": f"Bearer {token}"}