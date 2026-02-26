# groups/tests/test_api.py
#TODO: pytest groups/tests/ -v --reuse-db -p no:warnings

import pytest
from groups.models import Group, GroupMember
from django.contrib.auth import get_user_model

User = get_user_model()

# Tell pytest this entire file needs database access
pytestmark = pytest.mark.django_db

def test_create_group(groups_client, auth_headers_groups, test_user_groups):
    """Test creating a new group."""
    payload = {
        "name": "Math Class",
        "color": "#FF5733"
    }
    
    response = groups_client.post("/", json=payload, headers=auth_headers_groups)
    
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Math Class"
    assert data["color"] == "#FF5733"
    assert "invite_code" in data

    group = Group.objects.get(id=data["id"])
    member = GroupMember.objects.get(group=group, user=test_user_groups)
    assert member.rank == "ADMIN"

def test_list_groups(groups_client, auth_headers_groups, test_user_groups):
    """Test retrieving the list of groups for the authenticated user."""
    # Create an initial group directly directly to test listing
    payload = {"name": "Physics Class", "color": "#00FF00"}
    groups_client.post("/", json=payload, headers=auth_headers_groups)
    
    response = groups_client.get("/", headers=auth_headers_groups)
    
    assert response.status_code == 200
    data = response.json()
    
    # Because there might be other groups from different tests, we just check lengths and contents
    assert len(data) >= 1
    assert any(g["name"] == "Physics Class" for g in data)
    
    # Ensure rank is provided
    physics_group = next(g for g in data if g["name"] == "Physics Class")
    assert "rank" in physics_group

def test_join_group(groups_client, auth_headers_groups, test_user_groups, auth_headers_2_groups, test_user_2_groups):
    """Test joining a group using a valid invite code."""
    payload = {"name": "Chemistry Class", "color": "#0000FF"}
    create_response = groups_client.post("/", json=payload, headers=auth_headers_groups)
    invite_code = create_response.json()["invite_code"]
    group_id = create_response.json()["id"]
    
    join_payload = {"invite_code": invite_code}
    join_response = groups_client.post("/join", json=join_payload, headers=auth_headers_2_groups)
    
    assert join_response.status_code == 200
    assert join_response.json()["name"] == "Chemistry Class"
    
    group = Group.objects.get(id=group_id)
    member = GroupMember.objects.get(group=group, user=test_user_2_groups)
    assert member.rank == "MEMBER"

def test_get_group(groups_client, auth_headers_groups, test_user_groups):
    """Test retrieving a specific group by its ID."""
    # Create an initial group
    payload = {"name": "Biology Class", "color": "#FFFF00"}
    create_response = groups_client.post("/", json=payload, headers=auth_headers_groups)
    group_id = create_response.json()["id"]
    
    # Retrieve the group as member (admin)
    response = groups_client.get(f"/{group_id}", headers=auth_headers_groups)
    
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Biology Class"
    assert data["rank"] == "ADMIN"
    
def test_get_group_unauthorized(groups_client, auth_headers_2_groups):
    """Test retrieving a specific group fails if the user is not a member."""
    # Note: user 2 is not a member of a non-existent group (using id=9999).
    response = groups_client.get("/9999", headers=auth_headers_2_groups)
    assert response.status_code == 404
    
def test_update_group_settings(groups_client, auth_headers_groups, test_user_groups):
    """Test updating a group's settings (requires ADMIN rank)."""
    payload = {"name": "History Class", "color": "#333333"}
    create_response = groups_client.post("/", json=payload, headers=auth_headers_groups)
    group_id = create_response.json()["id"]
    
    update_payload = {"name": "Advanced History Class", "color": "#444444"}
    update_response = groups_client.patch(f"/{group_id}", json=update_payload, headers=auth_headers_groups)
    
    assert update_response.status_code == 200
    data = update_response.json()
    assert data["name"] == "Advanced History Class"
    assert data["color"] == "#444444"
