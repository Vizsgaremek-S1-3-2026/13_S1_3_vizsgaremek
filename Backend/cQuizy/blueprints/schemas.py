# blueprints/schemas.py
# AKA Projects Schemas

from ninja import Schema
from datetime import datetime
from typing import Optional

#! Project Schemas ==================================================
class ProjectCreateSchema(Schema):
    name: str
    desc: Optional[str] = None

class ProjectOutSchema(Schema):
    id: int
    name: str
    desc: Optional[str] = None
    creator_username: str
    date_created: datetime

    @staticmethod
    def resolve_creator_username(obj):
        return obj.creator.username

#! Nested Schemas ===================================================class AnswerNestedSchema(Schema):
    id: Optional[int] = None
    text: str
    is_correct: bool

class BlockNestedSchema(Schema):
    id: Optional[int] = None
    question: str
    type: str
    subtext: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    answers: List[AnswerNestedSchema]

class ProjectUpdateSchema(Schema):
    name: str
    desc: Optional[str] = None
    blocks: List[BlockNestedSchema]