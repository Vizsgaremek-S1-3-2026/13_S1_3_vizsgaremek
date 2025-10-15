from django.shortcuts import redirect
from django.contrib.auth import logout
# Create your views here.
def session_logout_view(request):
    logout(request)
    return redirect('/login/') # Redirect to the login page after logging out