from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone



#! Managers ==================================================
class CustomUserManager(models.Manager):
    """ Custom manager to return only active (not soft-deleted) Users. """
    def get_queryset(self):
        # We filter by both is_active and date_deleted for maximum security and correctness.
        return super().get_queryset().filter(is_active=True, date_deleted__isnull=True)



#! Models ==================================================
class CustomUser(AbstractUser):
    """
    This is our project-wide user model.
    It includes all default Django fields plus our custom profile and soft-delete fields.
    """
    # --- Profile Fields ---
    nickname = models.CharField(max_length=20, null=True, blank=True)
    pfp_url = models.URLField(
        max_length=200,
        default='https://img.icons8.com/?size=100&id=NcQNyxjmHvuB&format=png&color=000000'
    )

    # --- Soft-Delete Field ---
    date_deleted = models.DateTimeField(null=True, blank=True, verbose_name="Date Deleted")

    # --- Managers ---
    objects = CustomUserManager()   # The default manager. `CustomUser.objects.all()` will now only return active users.
    all_objects = models.Manager()  # A manager to access ALL users, including inactive/deleted ones.

    def __str__(self):
        return self.username

    def perform_soft_delete(self):
        """
        A helper method to correctly soft-delete a user by deactivating,
        anonymizing PII, and setting the soft-delete timestamp.
        """
        self.is_active = False
        self.date_deleted = timezone.now()
        
        # Anonymize Personally Identifiable Information (PII) for privacy compliance
        self.username = f"deleted_user_{self.id}"
        self.first_name = ""
        self.last_name = ""
        self.email = ""
        
        self.set_unusable_password()
        self.save()