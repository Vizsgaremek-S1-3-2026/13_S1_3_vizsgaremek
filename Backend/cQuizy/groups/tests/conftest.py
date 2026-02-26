import pytest
from ninja.testing import TestClient
from django.contrib.auth import get_user_model
from groups.api import router
from users.auth import generate_token

User = get_user_model()

@pytest.fixture
def groups_client():
    """Returns a Django Ninja TestClient for the groups router."""
    return TestClient(router)

@pytest.fixture
def test_user_groups(db):
    """Creates and returns a standard test user specifically for the groups app."""
    user, created = User.objects.get_or_create(
        username="testuser_groups",
        defaults={
            "email": "test_groups@email.com",
            "password": "strongpassword123",
            "first_name": "Test",
            "last_name": "Groups User"
        }
    )
    if not created:
        user.set_password("strongpassword123")
        user.save()
    return user

@pytest.fixture
def test_user_2_groups(db):
    """Creates and returns a second standard test user for joining groups tests."""
    user, created = User.objects.get_or_create(
        username="testuser_2_groups",
        defaults={
            "email": "test2_groups@email.com",
            "password": "strongpassword456",
            "first_name": "Test2",
            "last_name": "Groups User 2"
        }
    )
    if not created:
        user.set_password("strongpassword456")
        user.save()
    return user

@pytest.fixture
def auth_headers_groups(test_user_groups):
    """Generates a real JWT token for test_user_groups."""
    token = generate_token(test_user_groups)
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def auth_headers_2_groups(test_user_2_groups):
    """Generates a real JWT token for test_user_2_groups."""
    token = generate_token(test_user_2_groups)
    return {"Authorization": f"Bearer {token}"}
