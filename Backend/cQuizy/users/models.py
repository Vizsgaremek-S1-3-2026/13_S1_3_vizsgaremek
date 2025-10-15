from django.db import models
from django.contrib.auth.models import User

# Create your models here.
class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE) # Creates a one-to-one relationship with the User model and deletes the profile if the user is deleted
    nickname = models.CharField(
        max_length=20,
        null=True,
        blank=True
    )
    pfp_url = models.URLField(
        max_length=200,
        default='https://img.icons8.com/?size=100&id=NcQNyxjmHvuB&format=png&color=000000'
    )

    def __str__(self):
        return f'{self.user.username} Profile'