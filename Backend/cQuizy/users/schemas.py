# cQuizy/users/schemas.py

from ninja import Schema
from pydantic import Field, EmailStr, field_validator
from typing import Optional
from datetime import datetime
import re

#! User Output Schema ==================================================
# This is now the primary schema for displaying user data.
class UserOut(Schema):
    id: int
    username: str
    email: EmailStr
    first_name: str
    last_name: str
    nickname: Optional[str]
    pfp_url: str
    date_joined: Optional[datetime]

    class Config:
        from_attributes = True

#! User Settings Schemas (Inputs) =======================================
# Renamed from UpdateProfileSchema for clarity
class UpdateUserSchema(Schema):
    nickname: Optional[str] = None
    pfp_url: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None

class UpdateEmailSchema(Schema):
    email: str
    password: str 

class UpdatePasswordSchema(Schema):
    old_password: str
    new_password: str

class DeleteAccountSchema(Schema):
    password: str

#! Registration and Login Schemas =======================================
class RegisterSchema(Schema):
    username: str
    nickname: Optional[str] = None
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    pfp_url: Optional[str] = None

    @field_validator('username')
    def validate_username(cls, value):
        """
        Validates that the username contains only lowercase letters,
        numbers, and underscores, and is between 3 and 20 characters long.
        """
        # 1. Check for allowed characters using a regular expression.
        #    ^                - Start of the string
        #    [a-z0-9_]        - Allowed characters: lowercase a-z, numbers 0-9, underscore
        #    +                - One or more of the allowed characters
        #    $                - End of the string
        if not re.match('^[a-z0-9_]+$', value):
            raise ValueError('Username can only contain lowercase letters, numbers, and underscores.')

        # 2. Check for length.
        if not 3 <= len(value) <= 20:
            raise ValueError('Username must be between 3 and 20 characters long.')
        
        # 3. If all checks pass, return the original value.
        return value

class LoginSchema(Schema):
    username: str
    password: str

class TokenSchema(Schema):
    token: str