from ninja import Schema
from pydantic import Field, EmailStr
from typing import Optional

#! Profile ==================================================
#? Schema for displaying profile information (Output)
class ProfileOut(Schema):
    username: str = Field(..., alias="user.username") # Get username from the related User model
    pfp_url: str

#? Schema for updating the profile (Input)
class ProfileUpdate(Schema):
    pfp_url: str

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