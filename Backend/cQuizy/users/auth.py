import jwt
from datetime import datetime, timedelta
from ninja.security import HttpBearer
from django.conf import settings
from django.contrib.auth.models import User

# This class handles validating tokens sent by the user
class JWTAuth(HttpBearer):
    def authenticate(self, request, token):
        try:
            # Decode the token using your Django SECRET_KEY
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
            
            # Find the user based on the 'id' stored in the token payload
            user = User.objects.get(id=payload['id'])
            return user  # If successful, Ninja gets the user object
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
            # If the token is expired, invalid, or the user doesn't exist, auth fails.
            return None

# This function creates a new JWT for a user
def generate_token(user: User) -> str:
    # A token is valid for 1 day. You can change this.
    expiration_time = datetime.utcnow() + timedelta(days=1)
    
    payload = {
        'id': user.id,
        'username': user.username,
        'exp': expiration_time,  # Expiration Time
        'iat': datetime.utcnow()   # Issued At Time
    }
    
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')
    return token