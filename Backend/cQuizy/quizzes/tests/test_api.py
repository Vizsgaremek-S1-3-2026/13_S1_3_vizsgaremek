import pytest
from django.utils import timezone
from datetime import timedelta
from quizzes.models import Quiz, Submission

pytestmark = pytest.mark.django_db

def test_create_quiz(quizzes_client, teacher_auth_headers, test_group, test_project):
    """Test successful quiz creation by a teacher."""
    start_time = timezone.now() + timedelta(days=1)
    end_time = start_time + timedelta(hours=1)
    
    payload = {
        "group_id": test_group.id,
        "project_id": test_project.id,
        "date_start": start_time.isoformat(),
        "date_end": end_time.isoformat()
    }
    
    response = quizzes_client.post("/", json=payload, headers=teacher_auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["project"]["name"] == "Teszt Projekt"
    
    quiz = Quiz.objects.get(id=data["id"])
    assert quiz.group == test_group
    assert quiz.project == test_project

def test_start_quiz(quizzes_client, student_auth_headers, test_group, test_project):
    """Test student getting quiz questions (start quiz)."""
    now = timezone.now()
    quiz = Quiz.objects.create(
        group=test_group,
        project=test_project,
        date_start=now - timedelta(minutes=5),
        date_end=now + timedelta(hours=1)
    )
    
    response = quizzes_client.get(f"/{quiz.id}/start", headers=student_auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    assert data["project"]["name"] == "Teszt Projekt"
    assert len(data["project"]["blocks"]) == 1
    
    assert data["project"]["blocks"][0]["maintext"] == "1+1?"

def test_submit_quiz(quizzes_client, student_auth_headers, test_group, test_project):
    """Test a student submitting a quiz successfully."""
    now = timezone.now()
    quiz = Quiz.objects.create(
        group=test_group,
        project=test_project,
        date_start=now - timedelta(minutes=5),
        date_end=now + timedelta(hours=1)
    )
    
    block = test_project.blocks.first()
    correct_answer = block.answers.filter(is_correct=True).first()
    
    payload = {
        "quiz_id": quiz.id,
        "answers": [
            {
                "block_id": block.id,
                "option_id": correct_answer.id,
                "answer_text": None
            }
        ]
    }
    
    response = quizzes_client.post("/submit/", json=payload, headers=student_auth_headers)
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["percentage"] == "100.00"
    
    submission = Submission.objects.get(id=data["id"])
    assert submission.score == 1.0
    assert float(submission.percentage) == 100.0
