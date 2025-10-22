from ninja import Schema
from datetime import datetime

#! Groups ==================================================
#? Getting data about a group (Output)
class GroupOutSchema(Schema):
    id: int
    name: str
    date_created: datetime
    invite_code: str
class GroupWithRankOutSchema(GroupOutSchema):
    rank: str

#? Creating a group (Input)
class GroupCreateSchema(Schema):
    name: str

#? Joining a group (Input)
class GroupJoinSchema(Schema):
    invite_code: str