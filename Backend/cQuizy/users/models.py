# users/models.py

from django.db import models
from django.contrib.auth.models import AbstractUser, UserManager
from django.utils import timezone
from django.core.validators import RegexValidator
# We import the Group model to allow the CustomUser model to interact with it,
# specifically for cleaning up groups when a user is deleted.
from groups.models import Group


#! Managers ==================================================
class CustomUserManager(UserManager):
    """
    This is a custom manager for our CustomUser model.
    It inherits from Django's powerful UserManager, giving us access to
    helper methods like create_user() and create_superuser().

    We override the default get_queryset() method to ensure that all default
    queries (e.g., User.objects.all()) automatically filter for users who
    are both active and not soft-deleted.
    """
    def get_queryset(self):
        # By chaining filters, we ensure that only users who are both `is_active=True`
        # and have `date_deleted=NULL` are returned in standard queries.
        return super().get_queryset().filter(is_active=True, date_deleted__isnull=True)


#! Models ==================================================
class CustomUser(AbstractUser):
    """
    This is our project's primary user model, which replaces the default Django User.
    It inherits all the fields from AbstractUser (email, password, etc.)
    and adds our own custom fields for profile data and soft-deletion.
    """
    
    # This validator defines the rules for a valid username using a regular expression.
    # It will be enforced at the model level (e.g., in the Django admin) and the
    # schema level (for API requests).
    username_validator = RegexValidator(
        regex='^[a-z0-9_]+$',
        message='Username can only contain lowercase letters, numbers, and underscores.',
        code='invalid_username'
    )

    # We override the default 'username' field from AbstractUser to attach our custom validator.
    # This ensures data integrity directly at the database level.
    username = models.CharField(
        max_length=150,
        unique=True,
        help_text='Required. 150 characters or fewer. Lowercase letters, numbers, and underscores only.',
        validators=[username_validator],
        error_messages={
            'unique': "A user with that username already exists.",
        },
    )

    # These fields were previously on a separate 'Profile' model. Integrating them here
    # simplifies the data structure and improves query performance.
    nickname = models.CharField(max_length=20, null=True, blank=True)
    pfp_url = models.URLField(
        max_length=200,
        default='https://img.icons8.com/?size=100&id=NcQNyxjmHvuB&format=png&color=000000'
    )

    # This field is the core of our soft-delete functionality. If it is NULL, the user
    # is considered active. If it has a timestamp, the user is considered deleted.
    date_deleted = models.DateTimeField(null=True, blank=True, verbose_name="Date Deleted")

    # We assign our custom manager as the default 'objects' manager.
    objects = CustomUserManager()
    # We also keep a reference to the default, unfiltered manager for cases where we
    # need to access all users, including inactive or deleted ones (e.g., for login checks).
    all_objects = models.Manager()

    def __str__(self):
        # This provides a human-readable representation of the model instance in the admin and logs.
        return self.username

    def perform_soft_delete(self):
        """
        This is the definitive method for deleting a user, using a "Deactivation and Preservation" strategy.
        It ensures account access is revoked and private data is anonymized, while preserving
        the user's public identity for attribution on historical content.
        """
        # We use a local import here to avoid potential circular import errors.
        from django.utils import timezone
        
        # --- 1. Comprehensive Group Cleanup ---
        # We loop through all the user's active group memberships to perform cleanup.
        # 'group_memberships' is the `related_name` from the GroupMember model's ForeignKey.
        for membership in self.group_memberships.all():
            
            # First, we handle the critical case where the user is an admin.
            if membership.rank == 'ADMIN':
                group = membership.group
                # We check if this user is the *only* active admin in the group.
                other_admins_count = group.members.filter(rank='ADMIN').exclude(user=self).count()
                
                if other_admins_count == 0:
                    # If they are the last admin, we soft-delete the group to prevent it from
                    # becoming "orphaned" and unmanageable.
                    group.date_deleted = timezone.now()
                    group.save()
                    
                    # We then soft-delete all memberships within that now-deleted group.
                    for member in group.members.all():
                        if member.date_left is None:
                            member.date_left = timezone.now()
                            member.left_reason = 'GROUP_DELETED'
                            member.save()
            
            # Second, we handle the general case for all memberships. If the membership record is
            # currently active, we soft-delete it, effectively making the user "leave" the group.
            if membership.date_left is None:
                membership.date_left = timezone.now()
                membership.left_reason = 'LEFT' 
                membership.save()
        
        # --- 2. User Deactivation and Partial Anonymization ---
        
        # Deactivate the account to prevent all future logins.
        self.is_active = False
        self.date_deleted = timezone.now()
        
        # Anonymize unambiguous Personally Identifiable Information (PII) for privacy compliance.
        self.first_name = ""
        self.last_name = ""
        
        # Anonymize the email, which is a private credential. We use a unique pattern
        # to satisfy the database's UNIQUE constraint.
        self.email = f"deleted_user_{self.id}@deleted.com"
        
        # Invalidate the password hash to make login impossible.
        self.set_unusable_password()
        
        # The `username` and `nickname` fields are intentionally NOT changed
        # to preserve them for attribution on historical content.
        
        # Finally, we save all the changes to the user record.
        self.save()