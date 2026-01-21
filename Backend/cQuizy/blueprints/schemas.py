# blueprints/schemas.py
# AKA Projects Schemas

from ninja import Schema
from datetime import datetime
from typing import Optional, List

#! Project Creation Schema ==================================================
class ProjectCreateSchema(Schema):
    name: str
    desc: Optional[str] = None

#! Project JSON Output Schemas ===================================================
class AnswerOutSchema(Schema):
    id: int
    text: Optional[str] = None
    is_correct: bool
    points: int
    order: int
    match_text: Optional[str] = None
    gap_index: Optional[int] = None
    numeric_value: Optional[float] = None
    tolerance: Optional[float] = None

class BlockOutSchema(Schema):
    id: int
    order: int
    type: str
    maintext: Optional[str] = None
    question: Optional[str] = None # Just in case to resolve conflicts
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    gap_text: Optional[str] = None
    answers: List[AnswerOutSchema]

    @staticmethod
    def resolve_answers(obj):
        # Explicitly fetch all answers to ensure it returns a list, not a Manager
        return obj.answers.all()
    
    @staticmethod
    def resolve_question(obj): # Just in case to resolve conflicts (question -> maintext)
        return obj.maintext

class ProjectOutSchema(Schema):
    id: int
    name: str
    desc: Optional[str] = None
    creator_username: str
    date_created: datetime
    blocks: List[BlockOutSchema]

    @staticmethod
    def resolve_creator_username(obj):
        return obj.creator.username

#! Project JSON Input Schemas ===================================================
class AnswerUpdateSchema(Schema):
    id: Optional[int] = None
    text: Optional[str] = None
    is_correct: bool
    points: int = 1
    order: Optional[int] = 0
    match_text: Optional[str] = None
    gap_index: Optional[int] = None
    numeric_value: Optional[float] = None
    tolerance: Optional[float] = None

class BlockUpdateSchema(Schema):
    id: Optional[int] = None
    type: str
    maintext: Optional[str] = None
    question: Optional[str] = None # Just in case to resolve conflicts
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    gap_text: Optional[str] = None
    answers: List[AnswerUpdateSchema]

class ProjectUpdateSchema(Schema):
    name: str
    desc: Optional[str] = None
    blocks: List[BlockUpdateSchema]