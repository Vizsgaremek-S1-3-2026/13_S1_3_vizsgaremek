# cQuizy/users/auth.py

import jwt
from datetime import datetime, timedelta
from ninja.security import HttpBearer
from django.conf import settings
# To ensure our authentication works with our custom user model, we must import
# Django's helper function that retrieves the currently active user model for the project.
from django.contrib.auth import get_user_model

# We call this function once at the module level to get our CustomUser model class.
# From now on in this file, the variable 'User' will refer to our CustomUser model.
User = get_user_model()

# This class defines our authentication scheme. Ninja will use it to validate
# the JWT tokens sent by the user in the "Authorization" header.
class JWTAuth(HttpBearer):
    def authenticate(self, request, token):
        try:
            # First, we attempt to decode the token using our project's SECRET_KEY.
            # This single step verifies three critical things:
            # 1. The token was signed by us (the signature is valid).
            # 2. The token has not been tampered with.
            # 3. The token has not expired (jwt.decode checks the 'exp' claim automatically).
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
            
            # If decoding is successful, we extract the user's ID from the payload.
            # We then query our database to find the user with this ID.
            # This correctly queries the 'users_customuser' table.
            user = User.objects.get(id=payload['id'])
            
            # If the user is found, we return the user object. Ninja will then attach
            # this object to the request, making it available in our API endpoints.
            return user
            
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
            # This block catches all expected failure scenarios:
            # - ExpiredSignatureError: The token's 'exp' timestamp is in the past.
            # - InvalidTokenError: The token is malformed or the signature is wrong.
            # - User.DoesNotExist: The user ID in the token is no longer in our database.
            # In any of these cases, authentication fails, and we return None.
            return None

# This is a helper function to create a new JWT for a given user after they log in.
def generate_token(user: User) -> str:
    # We define how long the token will be valid. It's good practice to have
    # tokens that expire. Here, it's set to be valid for 1 day.
    expiration_time = datetime.utcnow() + timedelta(days=1)
    
    # The payload is the data we store inside the token. It's best to keep it small.
    # The user's ID is the most important piece of information for authentication.
    payload = {
        'id': user.id,
        'username': user.username, # Including username is helpful for debugging and display.
        'exp': expiration_time,    # The 'exp' claim is a standard for "Expiration Time".
        'iat': datetime.utcnow()     # The 'iat' claim is a standard for "Issued At Time".
    }
    
    # The jwt.encode function takes the payload, signs it with our project's
    # SECRET_KEY, and creates the final, secure token string that we can send to the client.
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')
    return token