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
    text: str
    is_correct: bool

class BlockOutSchema(Schema):
    id: int
    order: int
    question: str
    type: str
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    answers: List[AnswerOutSchema]

    @staticmethod
    def resolve_answers(obj):
        # Explicitly fetch all answers to ensure it returns a list, not a Manager
        return obj.answers.all()

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
    text: str
    is_correct: bool

class BlockUpdateSchema(Schema):
    id: Optional[int] = None
    question: str
    type: str
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    answers: List[AnswerUpdateSchema]

class ProjectUpdateSchema(Schema):
    name: str
    desc: Optional[str] = None
    blocks: List[BlockUpdateSchema]