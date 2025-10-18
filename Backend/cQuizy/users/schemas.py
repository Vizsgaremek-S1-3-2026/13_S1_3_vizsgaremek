from ninja import Schema
from pydantic import Field, EmailStr
from typing import Optional

#! Profile ==================================================
#? Schema for displaying profile information (Output)
class ProfileOut(Schema):
    username: str = Field(..., alias="user.username")
    email: EmailStr = Field(..., alias="user.email")
    first_name: str = Field(..., alias="user.first_name")
    last_name: str = Field(..., alias="user.last_name")
    nickname: str
    pfp_url: str

#! Profile Settings ==================================================
#? Schema for updating the profile (Input)
class UpdateProfileSchema(Schema):
    nickname: Optional[str] = None
    pfp_url: Optional[str] = None

#? Schema for updating the name (Input)
class UpdateNameSchema(Schema):
    first_name: str
    last_name: str

#? Schema for updating the email (Input)
class UpdateEmailSchema(Schema):
    email: str
    password: str 

#? Schema for updating the password (Input)
class UpdatePasswordSchema(Schema):
    old_password: str
    new_password: str
    repeat_password: str

#? Schema for deleting the account (Input)
class DeleteAccountSchema(Schema):
    username: str
    password: str

#! Registration and Login ==================================================
#? Schema for User Registration (Input)
class RegisterSchema(Schema):
    username: str
    nickname: Optional[str] = None
    first_name: str
    last_name: str
    email: EmailStr  # Ensures the input is a valid email format
    password: str
    pfp_url: Optional[str] = None

#? Schema for User Login (Input)
class LoginSchema(Schema):
    username: str # This might get the username or the email, but both are valid
    password: str

#? Schema for the response after a successful login (Output)
class TokenSchema(Schema):
    token: str