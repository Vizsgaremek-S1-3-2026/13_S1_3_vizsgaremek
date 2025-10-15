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



# Tests
@login_required # First, ensures the user is logged in at all
@user_passes_test(is_staff_member) # Then, checks if they are staff
def user_list_view(request):
    # Fetches all users AND their related profiles in a single, efficient query.

    all_users = User.objects.select_related('profile').all()

    context = {
        'users': all_users
    }

    return render(request, 'website/tests/users.html', context)
