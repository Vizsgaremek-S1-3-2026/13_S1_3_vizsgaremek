from ninja import Router
from django.contrib.auth import authenticate, login as django_login, logout as django_logout
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password
from django.views.decorators.csrf import csrf_protect

from django.db import IntegrityError
from pydantic import EmailStr, field_validator

#! Instead of NinjaAPI, we use Router
router = Router(tags=['users'])  # The 'tags' are great for organizing docs

#* Test Endpoint ##################################################
@router.get("/hello")
def hello(request):
    return {"message": "Hello, your API works!"}
