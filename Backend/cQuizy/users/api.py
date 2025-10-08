from ninja import NinjaAPI, Schema
from django.contrib.auth import authenticate, login as django_login, logout as django_logout
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password
from django.views.decorators.csrf import csrf_protect

from django.db import IntegrityError
from pydantic import EmailStr, field_validator

api = NinjaAPI()

#* Test Endpoint ##################################################
@api.get("/hello")
def hello(request, name: str):
    return {"message": f"Hai {name}, welcome to DUwUD 😎"}
