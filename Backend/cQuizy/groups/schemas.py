from ninja import Schema
from datetime import datetime
from typing import Optional

#! Groups ==================================================
#? Getting data about a group (Output)
class GroupOutSchema(Schema):
    id: int
    name: str
    date_created: datetime
    invite_code: str
    anticheat: bool
    kiosk: bool
class GroupWithRankOutSchema(GroupOutSchema):
    rank: str

#? Getting Data of Group Members
class UserBasicOut(Schema):
    id: int
    username: str
    first_name: str
    last_name: str
    nickname: Optional[str]
    pfp_url: Optional[str]

class MemberOutSchema(Schema):
    user: UserBasicOut
    rank: str
    date_joined: datetime

#? Updating group name (Input)
class GroupUpdateSchema(Schema):
    name: Optional[str] = None
    anticheat: Optional[bool] = None
    kiosk: Optional[bool] = None

#? Transferring group ownership (Input)
class GroupTransferSchema(Schema):
    user_id: int

#? Creating a group (Input)
class GroupCreateSchema(Schema):
    name: str

#? Joining a group (Input)
class GroupJoinSchema(Schema):
    invite_code: str