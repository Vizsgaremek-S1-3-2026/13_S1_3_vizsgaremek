from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from colorfield.fields import ColorField



#! Managers ==================================================
class ActiveManager(models.Manager):
    """ Custom manager to return only active (not soft-deleted) Groups. """
    def get_queryset(self):
        return super().get_queryset().filter(date_deleted__isnull=True)

class ActiveGroupMemberManager(models.Manager):
    """ Custom manager to return only active (not soft-deleted) Group Members. """
    def get_queryset(self):
        return super().get_queryset().filter(date_left__isnull=True)



#! Tables ==================================================
#? Groups
class Group(models.Model):
    """
    Represents a group to which tests and users can be assigned.
    """
    name = models.CharField(max_length=100, verbose_name="Group Name")
    date_created = models.DateTimeField(auto_now_add=True, verbose_name="Date Created")
    invite_code = models.CharField(max_length=20, unique=True, verbose_name="Invite Code")
    color = ColorField(default="#555555", verbose_name="Group Color")
    anticheat = models.BooleanField(default=False, verbose_name="Anti-cheat")
    kiosk = models.BooleanField(default=False, verbose_name="Kiosk Mode")
    date_deleted = models.DateTimeField(null=True, blank=True, verbose_name="Date Deleted") #* Soft Delete

    objects = ActiveManager()
    all_objects = models.Manager()

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "Group"
        verbose_name_plural = "Groups"



#? Members
class GroupMember(models.Model):
    """
    Manages the relationship between users and groups,
    defining the user's role within a specific group.
    """
    RANK_CHOICES = [
        ('ADMIN', 'Admin'),
        ('MEMBER', 'Member'),
    ]
    LEAVE_REASON_CHOICES = [
        ('GROUP_DELETED', 'Group Deleted'),
        ('KICKED', 'Kicked by Admin'),
        ('LEFT', 'Left Voluntarily'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="members")
    rank = models.CharField(
        max_length=10,
        choices=RANK_CHOICES,
        default='MEMBER',
        verbose_name="Rank"
    )
    date_joined = models.DateTimeField(auto_now_add=True, verbose_name="Date Joined")
    date_left = models.DateTimeField(null=True, blank=True, verbose_name="Date Left") #* Soft Delete
    left_reason = models.CharField(
        max_length=15, # Needs to be long enough for 'GROUP_DELETED', 'KICKED' and 'LEFT'
        choices=LEAVE_REASON_CHOICES,
        null=True,
        blank=True,
        verbose_name="Left Reason"
    ) #* Soft Delete Bonus

    objects = ActiveGroupMemberManager()
    all_objects = models.Manager()

    class Meta:
        # Ensures a user can only be a member of a group once
        unique_together = ('user', 'group')
        verbose_name = "Group Member"
        verbose_name_plural = "Group Members"

    def __str__(self):
        return f"{self.user.username} - {self.group.name} ({self.get_rank_display()})"



#? Grades (not yet implemented)
class GradePercentage(models.Model):
    """
    Defines the percentage ranges for grades within a specific group.
    E.g., for Group A, 90-100% is a '5', 80-89% is a '4', etc.
    """
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="grade_percentages", verbose_name="Group")
    name = models.CharField(max_length=50, verbose_name="Grade Name")
    min_percentage = models.PositiveIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        verbose_name="Minimum Percentage"
    )
    max_percentage = models.PositiveIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        verbose_name="Maximum Percentage"
    )
    is_active = models.BooleanField(default=True, verbose_name="Active") #* Soft Delete

    class Meta:
        # Ensures that for a given group, grade names are unique (e.g., you can't have two '5' grades)
        unique_together = ('group', 'name')
        verbose_name = "Grade Percentage"
        verbose_name_plural = "Grade Percentages"
        ordering = ['group', '-max_percentage'] # Optional: Orders grades from highest to lowest for each group

    def __str__(self):
        return f"{self.group.name}: {self.name} ({self.min_percentage}% - {self.max_percentage}%)"