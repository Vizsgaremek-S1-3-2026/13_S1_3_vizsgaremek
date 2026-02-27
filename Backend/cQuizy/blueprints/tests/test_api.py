import pytest
from blueprints.models import Project, Block

pytestmark = pytest.mark.django_db

def test_create_project(blueprints_client, auth_headers_blueprints, test_user_blueprints):
    """Test successful project creation."""
    payload = {
        "name": "Test Project",
        "desc": "This is a test project"
    }
    
    response = blueprints_client.post("/", json=payload, headers=auth_headers_blueprints)
    
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Teszt Projekt"
    
    project = Project.objects.get(id=data["id"])
    assert project.name == "Teszt Projekt"
    assert project.creator == test_user_blueprints

def test_get_project_details(blueprints_client, auth_headers_blueprints, test_user_blueprints):
    """Test retrieving full project details."""
    project = Project.objects.create(name="Projekt", creator=test_user_blueprints)
    
    response = blueprints_client.get(f"/{project.id}/", headers=auth_headers_blueprints)
    
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == project.id
    assert data["name"] == "Projekt"

def test_update_full_project_with_blocks(blueprints_client, auth_headers_blueprints, test_user_blueprints):
    """Test complex update logic: replacing project name and managing blocks/answers."""
    project = Project.objects.create(name="Régi Név", creator=test_user_blueprints)
    
    payload = {
        "name": "Új Név",
        "desc": "Új Leírás",
        "blocks": [
            {
                "type": "single",
                "maintext": "Mennyi 2+2?",
                "subtext": "",
                "answers": [
                    {"text": "3", "is_correct": False, "points": 0},
                    {"text": "4", "is_correct": True, "points": 1}
                ]
            }
        ]
    }
    
    response = blueprints_client.put(f"/{project.id}/", json=payload, headers=auth_headers_blueprints)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Új Név"
    
    project.refresh_from_db()
    assert project.name == "Új Név"
    assert project.blocks.count() == 1
    
    block = project.blocks.first()
    assert block.type == "single_choice"
    assert block.maintext == "What is 2+2?"
    assert block.answers.count() == 2
