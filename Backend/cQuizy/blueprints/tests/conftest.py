import pytest
from ninja.testing import TestClient
from django.contrib.auth import get_user_model
from blueprints.api import router
from users.auth import generate_token

User = get_user_model()

@pytest.fixture
def blueprints_client():
    """Returns a Django Ninja TestClient for the blueprints router."""
    return TestClient(router)

@pytest.fixture
def test_user_blueprints(db):
    """Creates and returns a standard test user specifically for the blueprints app."""
    user, created = User.objects.get_or_create(
        username="testuser_blueprints",
        defaults={
            "email": "test_blueprints@email.com",
            "password": "strongpassword123",
            "first_name": "Test",
            "last_name": "Blueprints User"
        }
    )
    if not created:
        user.set_password("strongpassword123")
        user.save()
    return user

@pytest.fixture
def auth_headers_blueprints(test_user_blueprints):
    """Generates a real JWT token for test_user_blueprints."""
    token = generate_token(test_user_blueprints)
    return {"Authorization": f"Bearer {token}"}
