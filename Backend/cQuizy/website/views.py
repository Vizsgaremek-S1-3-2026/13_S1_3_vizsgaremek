#cQuizy/website/views.py

from django.shortcuts import render
from django.http import HttpResponse
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required, user_passes_test

# Definitions
def is_staff_member(user):
    return user.is_staff

# Pages
def home(request):
    return render(request, 'website/pages/home.html')
def login(request):
    return render(request, 'website/pages/login.html')
def register(request):
    return render(request, 'website/pages/register.html')
def profile(request):
    return render(request, 'website/pages/profile.html')
def groups(request):
    return render(request, 'website/pages/groups.html')
def projects(request):
    return render(request, 'website/pages/projects.html')
def builder(request):
    return render(request, 'website/pages/builder.html')
