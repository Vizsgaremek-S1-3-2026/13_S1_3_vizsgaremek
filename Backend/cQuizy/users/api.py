# cQuizy/users/api.py

from ninja import Router
from ninja.errors import HttpError
from django.contrib.auth import authenticate, get_user_model
from django.utils import timezone
from django.db import transaction
from django.db.models import Q

from .schemas import (
    UserOut,
    UpdateUserSchema,
    UpdateEmailSchema,
    UpdatePasswordSchema,
    DeleteAccountSchema,
    RegisterSchema,
    LoginSchema,
    TokenSchema,
)

from .auth import generate_token, JWTAuth

#? Get the CustomUser model from settings
User = get_user_model()

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Users'])  # The 'tags' are great for organizing docs



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
    # --- CHANGE: Simplified docstring ---
    Handles user registration with the CustomUser model in a single transaction.
    """
    # 1. --- VALIDATION ---
    if User.objects.filter(username=payload.username).exists():
        raise HttpError(400, "Username already taken")
    if User.objects.filter(email=payload.email).exists():
        raise HttpError(400, "Email already registered")

    # The CustomUser model can be created directly in one step.
    user = User.objects.create_user(
        username=payload.username,
        email=payload.email,
        password=payload.password,
        first_name=payload.first_name,
        last_name=payload.last_name,
        nickname=payload.nickname,
        # Set the pfp_url from the payload, or use the model's default if not provided.
        pfp_url=payload.pfp_url or User._meta.get_field('pfp_url').get_default()
    )
    
    # 5. --- RETURN SUCCESS RESPONSE ---
    return {"success": f"User '{user.username}' created successfully."}

#? Login --------------------------------------------------
@router.post("/login", response=TokenSchema, summary="Login for API and create Django session")
def login(request, payload: LoginSchema):
    # The input from the user (could be username or email)
    login_identifier = payload.username 

    # This allows us to give a more generic error message.
    try:
        user_query = User.all_objects.get(
            Q(username=login_identifier) | Q(email=login_identifier)
        )
    except User.DoesNotExist:
        # User not found at all.
        raise HttpError(401, "Invalid credentials")

    # Verify the password. The authenticate function checks is_active=True by default.
    user = authenticate(username=user_query.username, password=payload.password)
    
    if user is not None:
        # Manually update the last_login timestamp since we are not using Django's default login() method.
        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])

        # 1. Create the session cookie for the Django Admin (This is still commented out as per your original)
        ''' This will break the login for admin users
        if user.is_staff:
            django_session_login(request, user)
        '''
        
        # 2. Generate the JWT for API clients (JS, Flutter)
        token = generate_token(user)
        return {"token": token}
    
    else:
        # This handles both wrong password and inactive/soft-deleted user cases.
        raise HttpError(401, "Invalid credentials or inactive account")

#? Logout --------------------------------------------------
@router.post("/logout", auth=JWTAuth(), summary="Log out the current user")
def logout(request):
    # Since JWT is stateless, logout is primarily a client-side action.
    # The client must delete its token.
    # This endpoint is provided for API completeness and can be used
    # in the future for token denylisting if needed.
    return {"success": "User logged out successfully."}



#! Current User ("Me") Endpoints ==================================================
#? User Info --------------------------------------------------
@router.get("/me", response=UserOut, auth=JWTAuth(), summary="Get the logged-in user's data")
def get_me(request):
    # If the token was valid, the authenticated user is attached to the request
    # by our JWTAuth class. We can access it with `request.auth`.
    # It is already the full CustomUser object.
    return request.auth

#? Update User Data --------------------------------------------------
@router.patch("/me", response=UserOut, auth=JWTAuth(), summary="Update the logged-in user's data")
def update_me(request, payload: UpdateUserSchema):
    user = request.auth
    
    # The payload is a Pydantic model, .dict() converts it to a dictionary
    # exclude_unset=True means we only get the fields the user actually sent
    update_data = payload.dict(exclude_unset=True)
    
    for key, value in update_data.items():
        setattr(user, key, value)
        
    user.save()
    return user

#? Change Email --------------------------------------------------
@router.post("/me/change-email", auth=JWTAuth(), summary="Change the user's email address")
def change_email(request, payload: UpdateEmailSchema):
    user = request.auth
    
    # 1. Verify the user's current password
    if not user.check_password(payload.password):
        raise HttpError(401, "Invalid password")
        
    # 2. Check if the new email is already in use
    if User.objects.filter(email=payload.email).exclude(id=user.id).exists():
        raise HttpError(400, "This email address is already registered.")
        
    # 3. Update and save
    user.email = payload.email
    user.save()
    return {"success": "Email updated successfully."}

#? Change Password --------------------------------------------------
@router.post("/me/change-password", auth=JWTAuth(), summary="Change the user's password")
def change_password(request, payload: UpdatePasswordSchema):
    user = request.auth

    # 1. Verify the old password
    if not user.check_password(payload.old_password):
        raise HttpError(401, "Invalid old password")
    
    # 2. Set the new password (set_password handles the hashing)
    user.set_password(payload.new_password)
    user.save()
    return {"success": "Password updated successfully."}

#? Delete Account --------------------------------------------------
@router.delete("/me", auth=JWTAuth(), summary="Soft-delete the current user's account after password confirmation")
def delete_user(request, payload: DeleteAccountSchema):
    """
    Soft-deletes the currently authenticated user's account.

    This is a destructive action and requires the user to provide their
    current password for verification before proceeding.
    """
    user = request.auth
    
    # 1. --- VERIFICATION ---
    # Verify the password provided in the request body against the user's current password.
    if not user.check_password(payload.password):
        raise HttpError(401, "Invalid password")

    # 2. --- SOFT DELETION ---
    # If the password is correct, call the custom soft-delete method
    # defined on the CustomUser model.
    user.perform_soft_delete()
    
    return {"success": "User account has been successfully deleted."}