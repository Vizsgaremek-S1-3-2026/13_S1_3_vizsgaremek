import pytest
from ninja.testing import TestClient
from django.contrib.auth import get_user_model
from django.utils import timezone
from quizzes.api import router
from users.auth import generate_token
from groups.models import Group, GroupMember
from blueprints.models import Project, Block, Answer

User = get_user_model()

@pytest.fixture
def quizzes_client():
    """Returns a Django Ninja TestClient for the quizzes router."""
    return TestClient(router)

@pytest.fixture
def teacher_user(db):
    user, _ = User.objects.get_or_create(username="teacher_user", email="teacher@test.com")
    user.set_password("pass123")
    user.save()
    return user

@pytest.fixture
def student_user(db):
    user, _ = User.objects.get_or_create(username="student_user", email="student@test.com")
    user.set_password("pass123")
    user.save()
    return user

@pytest.fixture
def teacher_auth_headers(teacher_user):
    token = generate_token(teacher_user)
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def student_auth_headers(student_user):
    token = generate_token(student_user)
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def test_group(db, teacher_user, student_user):
    group = Group.objects.create(name="Teszt Csoport", creator=teacher_user, is_active=True)
    GroupMember.objects.create(group=group, user=teacher_user, rank='ADMIN')
    GroupMember.objects.create(group=group, user=student_user, rank='MEMBER')
    return group

@pytest.fixture
def test_project(db, teacher_user):
    project = Project.objects.create(name="Teszt Projekt", creator=teacher_user)
    block = Block.objects.create(project=project, type='single_choice', maintext="1+1?", order=1)
    Answer.objects.create(block=block, text="2", is_correct=True, points=1, order=1)
    Answer.objects.create(block=block, text="3", is_correct=False, points=0, order=2)
    return project
