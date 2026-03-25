# quizzes/schemas.py

from ninja import Schema
from enum import Enum
from typing import Optional, List
from datetime import datetime
from django.utils import timezone # Needed for server_now

#! Quiz Schemas (Linking Project to a Group)
class QuizCreateSchema(Schema):
    project_id: int
    group_id: int
    date_start: datetime
    date_end: datetime

class QuizUpdateSchema(Schema):
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

# --- Safe Schemas for taking a test ---
class StudentOptionSchema(Schema):
    id: int
    text: Optional[str] = None
    match_text: Optional[str] = None
    gap_index: Optional[int] = None

class StudentBlockSchema(Schema):
    id: int
    order: int
    type: str # <--- Resolves to frontend short-code
    maintext: Optional[str] = None
    question: Optional[str] = None 
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    gap_text: Optional[str] = None
    answers: List[StudentOptionSchema]

    @staticmethod
    def resolve_answers(obj):
        return obj.answers.all()

    @staticmethod
    def resolve_question(obj): 
        return obj.maintext

    @staticmethod
    def resolve_type(obj):
        """
        Maps Backend DB types back to Frontend Short Codes.
        CRITICAL FOR FRONTEND RENDERING.
        """
        mapping = {
            'single_choice': 'single',
            'multiple_choice': 'multiple',
            'text_input': 'text',
            'text_static': 'text_block',
            
            'divider': 'divider',
            'matching': 'matching',
            'ordering': 'ordering',
            'sentence_ordering': 'sentence_ordering',
            'gap_fill': 'gap_fill',
            'range': 'range',
        }
        # Return mapped value, or original if not found
        return mapping.get(obj.type, obj.type)

class QuizContentSchema(Schema):
    id: int
    title: str
    desc: Optional[str] = None
    anticheat_enabled: bool
    kiosk_enabled: bool
    date_end: datetime
    server_now: datetime # <--- CRITICAL FOR TIMER SYNC
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
        return obj.project.blocks.all()
    
    @staticmethod
    def resolve_server_now(obj):
        # Returns current server time every time this endpoint is hit
        return timezone.now()


#! Event Schemas
class EventTypeEnum(str, Enum):
    TEST_START = "TEST_START"
    TEST_FINISH = "TEST_FINISH"
    STUDENT_CHEAT = "STUDENT_CHEAT"

class EventCreateSchema(Schema):
    quiz_id: int
    type: EventTypeEnum
    desc: Optional[str] = None
    answer: Optional[str] = None

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
    is_locked: bool          # True if there is an ACTIVE event
    is_closed: bool          # True if teacher chose "CLOSE"
    active_event_id: Optional[int] = None
    message: str

class ResolveEventSchema(Schema):
    decision: str  # "UNLOCK" or "CLOSE"
    note: Optional[str] = None


#! Submission Schemas
class AnswerInputSchema(Schema):
    block_id: int
    answer_text: Optional[str] = ""
    option_id: Optional[int] = None

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
    group_id: int

    @staticmethod
    def resolve_student_name(obj):
        return obj.student.username

    @staticmethod
    def resolve_quiz_project(obj):
        return obj.quiz.project.name
    
    @staticmethod
    def resolve_grade_value(obj):
        return obj.grade.value if obj.grade else None

    @staticmethod
    def resolve_group_id(obj):
        return obj.quiz.group.id 

# --- Detailed View for Teachers ---
class SubmittedAnswerDetailSchema(Schema):
    id: int
    block_id: int
    block_order: int
    block_question: str
    student_answer: str
    points_awarded: int

    @staticmethod
    def resolve_block_question(obj):
        return obj.block.maintext

    @staticmethod
    def resolve_student_answer(obj):
        return obj.answer
    
    @staticmethod
    def resolve_block_id(obj):
        return obj.block.id

    @staticmethod
    def resolve_block_order(obj):
        return obj.block.order

class SubmissionDetailSchema(Schema):
    id: int
    student_name: str
    percentage: float
    grade_value: Optional[str] = None
    group_id: int
    answers: List[SubmittedAnswerDetailSchema]

    @staticmethod
    def resolve_student_name(obj):
        return obj.student.username
    
    @staticmethod
    def resolve_answers(obj):
        return obj.answers.all().select_related('block').order_by('block__order')

    @staticmethod
    def resolve_grade_value(obj):
        return obj.grade.value if obj.grade else None

    @staticmethod
    def resolve_group_id(obj):
        return obj.quiz.group.id

class QuizStatsSchema(Schema):
    average_score: float
    max_score: float
    min_score: float
    submission_count: int

# --- Update Points ---
class PointUpdateItemSchema(Schema):
    submitted_answer_id: int
    new_points: int

class PointUpdatePayload(Schema):
    updates: List[PointUpdateItemSchema]

# --- Update Grade ---
class GradeUpdateSchema(Schema):
    new_grade: str

# --- Quiz Status ---
class StudentBasicSchema(Schema):
    id: int
    username: str

class QuizStatusOutSchema(Schema):
    writing: List[StudentBasicSchema]
    locked: List[StudentBasicSchema]
    suspended: List[StudentBasicSchema]
    finished: List[StudentBasicSchema]
    idle: List[StudentBasicSchema]