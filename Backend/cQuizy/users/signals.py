from django.db.models.signals import post_save
from django.contrib.auth.models import User
from django.dispatch import receiver
from .models import Profile

@receiver(post_save, sender=User) #? Listens for the post_save signal from the User model, every time a User is created or updated
def create_user_profile(sender, instance, created, **kwargs): #? When a User is created, create a Profile for them
    if created: #? If the User is created (not updated)
        Profile.objects.create(user=instance) #? Create a Profile for the newly created User