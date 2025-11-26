# quizzes/schemas.py

from ninja import Schema
from typing import Optional, List
from datetime import datetime

#! Quiz Schemas (Linking Project to a Group)
class QuizCreateSchema(Schema):
    project_id: int
    group_id: int
    date_start: datetime
    date_end: datetime

class QuizOutSchema(Schema):
    id: int
    project_name: str
    group_name: str
    date_start: datetime
    date_end: datetime

    @staticmethod
    def resolve_project_name(obj):
        return obj.project.name

    @staticmethod
    def resolve_group_name(obj):
        return obj.group.name

# --- Safe Schemas for taking a test (No 'is_correct' or 'points') ---
class StudentOptionSchema(Schema):
    id: int
    text: str 
    # Important: Correctness and Points hidden from student

class StudentBlockSchema(Schema):
    id: int
    order: int
    type: str
    question: str
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    answers: List[StudentOptionSchema]

    @staticmethod
    def resolve_answers(obj):
        return obj.answers.all()

class QuizContentSchema(Schema):
    id: int
    title: str
    desc: Optional[str] = None
    anticheat_enabled: bool
    kiosk_enabled: bool
    date_end: datetime 
    blocks: List[StudentBlockSchema]

    @staticmethod
    def resolve_title(obj):
        return obj.project.name
    
    @staticmethod
    def resolve_desc(obj):
        return obj.project.desc
    
    @staticmethod
    def resolve_anticheat_enabled(obj):
        return obj.group.anticheat
    
    @staticmethod
    def resolve_kiosk_enabled(obj):
        return obj.group.kiosk
    
    @staticmethod
    def resolve_blocks(obj):
        # We assume blocks are prefetched in the View
        return obj.project.blocks.all()


#! Event Schemas
class EventCreateSchema(Schema):
    quiz_id: int
    type: str
    desc: str

class EventOutSchema(Schema):
    id: int
    student_name: str
    type: str
    status: str
    created_at: str

    @staticmethod
    def resolve_student_name(obj):
        return obj.student.username

    @staticmethod
    def resolve_created_at(obj):
        return str(obj.date_created)

class StudentLockStatusSchema(Schema):
    is_locked: bool
    active_event_id: Optional[int] = None
    message: str

class ResolveEventSchema(Schema):
    action: str = "unlock"
    note: Optional[str] = None


#! Submission Schemas
class AnswerInputSchema(Schema):
    block_id: int
    answer_text: str

class SubmissionCreateSchema(Schema):
    quiz_id: int
    answers: List[AnswerInputSchema]

class SubmissionOutSchema(Schema):
    id: int
    student_name: str
    quiz_project: str
    percentage: float
    grade_value: Optional[str] = None
    date_submitted: datetime

    @staticmethod
    def resolve_student_name(obj):
        return obj.student.username

    @staticmethod
    def resolve_quiz_project(obj):
        return obj.quiz.project.name
    
    @staticmethod
    def resolve_grade_value(obj):
        return obj.grade.value if obj.grade else None

# --- Detailed View for Teachers ---
class SubmittedAnswerDetailSchema(Schema):
    id: int
    block_question: str
    student_answer: str
    points_awarded: int

    @staticmethod
    def resolve_block_question(obj):
        return obj.block.question

class SubmissionDetailSchema(Schema):
    id: int
    student_name: str
    percentage: float
    answers: List[SubmittedAnswerDetailSchema]

    @staticmethod
    def resolve_student_name(obj):
        return obj.student.username
    
    @staticmethod
    def resolve_answers(obj):
        return obj.answers.all()

# --- Update Points ---
class PointUpdateItemSchema(Schema):
    submitted_answer_id: int
    new_points: int

class PointUpdatePayload(Schema):
    updates: List[PointUpdateItemSchema]