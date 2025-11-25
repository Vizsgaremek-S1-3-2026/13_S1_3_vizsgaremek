from ninja import Schema
from datetime import datetime
from typing import Optional

#! Groups ==================================================
#? Getting data about a group (Output)
class GroupOutSchema(Schema):
    id: int
    name: str
    date_created: datetime
    invite_code: str  # The raw 8-character code (e.g., "2k6o1u7p")
    color: str        # The hex color code for the group (e.g., "#555555")
    anticheat: bool
    kiosk: bool

    # --- Custom field resolved by a method below ---
    invite_code_formatted: str # The user-friendly version (e.g., "2k6o-1u7p")

    @staticmethod
    def resolve_invite_code_formatted(obj):
        """
        This function tells Ninja how to get the value for 'invite_code_formatted'.
        It calls the get_formatted_invite_code() method on the Group model instance ('obj').
        """
        # 'obj' is the Group model instance passed by Ninja
        return obj.get_formatted_invite_code()

class GroupWithRankOutSchema(GroupOutSchema):
    """
    This schema inherits all fields from GroupOutSchema (including our new ones)
    and simply adds the user's rank within that group.
    """
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
    color: Optional[str] = None
    anticheat: Optional[bool] = None
    kiosk: Optional[bool] = None

#? Transferring group ownership (Input)
class GroupTransferSchema(Schema):
    user_id: int

#? Creating a group (Input)
class GroupCreateSchema(Schema):
    name: str
    color: str

#? Joining a group (Input)
class GroupJoinSchema(Schema):
    invite_code: str