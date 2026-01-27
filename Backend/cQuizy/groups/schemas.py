from ninja import Schema
from datetime import datetime
from typing import Optional
import re
from pydantic import validator

#! Helper Functions ==================================================
#? Color Code Validation
def validate_hex_color(v: Optional[str]) -> Optional[str]:
    """
    Validates and formats a hex color code.
    Input: "ff0000", "#ff0000", "FF0000"
    Output: "#FF0000"
    """
    if not v:
        return v
    
    # Remove hash if present
    clean_hex = v.lstrip('#')
    
    # Check length (must be 6 chars for standard hex)
    if len(clean_hex) != 6:
        raise ValueError("Color must be a valid 6-character hex code (e.g. #FF5500)")
    
    # Check if valid hex characters
    if not re.fullmatch(r'[0-9A-Fa-f]{6}', clean_hex):
        raise ValueError("Color contains invalid characters. Use 0-9 and A-F.")
        
    # Return formatted uppercase string with hash
    return f"#{clean_hex.upper()}"



#! Groups ==================================================
#? Getting data about a group (Output)
class GroupOutSchema(Schema):
    id: int
    name: str
    date_created: datetime
    invite_code: Optional[str] = None  # The raw 8-character code (e.g., "2k6o1u7p")
    invite_code_formatted: Optional[str] = None # The user-friendly version (e.g., "2k6o-1u7p")
    color: str        # The hex color code for the group (e.g., "#555555")
    anticheat: bool
    kiosk: bool
    
    # Only group owners and admins will be able to see the invite code
    @staticmethod
    def resolve_invite_code(obj):
        rank = getattr(obj, 'rank', None)
        if rank in ["ADMIN", "SUPERUSER"]:
            return obj.invite_code
        return None
    @staticmethod
    def resolve_invite_code_formatted(obj):
        rank = getattr(obj, 'rank', None)
        if rank in ["ADMIN", "SUPERUSER"]:
            return obj.get_formatted_invite_code()
        return None

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

    @validator('color')
    def validate_color_format(cls, v):
        return validate_hex_color(v)

#? Transferring group ownership (Input)
class GroupTransferSchema(Schema):
    user_id: int

#? Creating a group (Input)
class GroupCreateSchema(Schema):
    name: str
    color: str

    @validator('color')
    def validate_color_format(cls, v):
        return validate_hex_color(v)

#? Joining a group (Input)
class GroupJoinSchema(Schema):
    invite_code: str

#? Deleting a group (Input)
class GroupDeleteSchema(Schema):
    password: str