from ninja import Router
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from django.contrib.auth import login as django_session_login
from django.db import transaction
from django.db.models import Q

from .models import Profile
from .schemas import RegisterSchema, LoginSchema, TokenSchema, ProfileOut
from .auth import generate_token, JWTAuth

#? Instead of NinjaAPI, we use Router
router = Router(tags=['users'])  # The 'tags' are great for organizing docs



#! Test Endpoint ==================================================
@router.get("/hello")
def hello(request):
    return {"message": "Hello, your API works!"}



#! Register & Login Endpoints ==================================================
#? Registration --------------------------------------------------
@router.post("/register", summary="Register a new user")
@transaction.atomic
def register(request, payload: RegisterSchema):
    """
    Handles user registration in a single, atomic database transaction.
    It now correctly handles profiles auto-created by signals.
    """
    # 1. --- VALIDATION ---
    if User.objects.filter(username=payload.username).exists():
        return router.api.create_response(request, {"error": "Username already taken"}, status=400)
    if User.objects.filter(email=payload.email).exists():
        return router.api.create_response(request, {"error": "Email already registered"}, status=400)

    # 2. --- PREPARE USER DATA ---
    user_data = {
        'username': payload.username,
        'email': payload.email,
        'password': payload.password,
        'first_name': payload.first_name,
        'last_name': payload.last_name
    }

    # 3. --- CREATE THE USER ---
    # When this line runs, your signal fires and creates a default Profile instance.
    user = User.objects.create_user(**user_data)
    
    # 4. --- GET AND UPDATE THE AUTO-CREATED PROFILE ---
    # The post_save signal on the User model already created a default Profile.
    # Instead of creating another one (which caused the IntegrityError), we now
    # get the existing one and update it with the data from the form.
    profile = Profile.objects.get(user=user)

    # Update the profile fields from the payload.
    profile.nickname = payload.nickname
    if payload.pfp_url and payload.pfp_url.strip() != '':
        profile.pfp_url = payload.pfp_url
    
    # Save the changes to the existing profile in the database.
    profile.save()
    
    # 5. --- RETURN SUCCESS RESPONSE ---
    return {"success": f"User '{user.username}' created successfully."}

#? Login --------------------------------------------------
@router.post("/login", response=TokenSchema, summary="Login for API and create Django session")
def login(request, payload: LoginSchema):
    # The input from the user (could be username or email)
    login_identifier = payload.username 

    # Try to find the user by username or email
    try:
        user_query = User.objects.get(
            Q(username=login_identifier) | Q(email=login_identifier)
        )
    except User.DoesNotExist:
        return router.api.create_response(request, {"error": "Invalid credentials"}, status=401)

    # Verify the password
    user = authenticate(username=user_query.username, password=payload.password)
    
    if user is not None:
        # ** THE UNIFIED LOGIN LOGIC **
        # 1. Create the session cookie for the Django Admin
        django_session_login(request, user)
        
        # 2. Generate the JWT for API clients (JS, Flutter)
        token = generate_token(user)
        return {"token": token}
    
    else:
        return router.api.create_response(request, {"error": "Invalid credentials"}, status=401)

#? Logout --------------------------------------------------
@router.post("/logout", auth=JWTAuth(), summary="Log out the current user")
def logout(request):
    # Since JWT is stateless, logout is primarily a client-side action.
    # The client must delete its token.
    # This endpoint is provided for API completeness and can be used
    # in the future for token denylisting if needed.
    return {"success": "User logged out successfully."}



#! Profile Endpoints ==================================================
#? Profile Info --------------------------------------------------
@router.get("/profile/me", response=ProfileOut, auth=JWTAuth(), summary="Get the logged-in user's profile")
def get_my_profile(request):
    # If the token was valid, the authenticated user is attached to the request
    # by our JWTAuth class. We can access it with `request.auth`.
    user = request.auth
    return user.profile # Assumes a one-to-one 'profile' relation on the User model

#? Delete Profile --------------------------------------------------
@router.delete("/profile/me", auth=JWTAuth(), summary="Delete the current user's account")
def delete_user(request):
    # The authenticated user is available from the token
    user = request.auth
    
    # The on_delete=models.CASCADE on your Profile model's OneToOneField
    # will handle deleting the associated profile automatically.
    user.delete()
    
    return {"success": "User account deleted successfully."}