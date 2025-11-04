from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator

class Group(models.Model):
    """
    Represents a group to which tests and users can be assigned.
    """
    name = models.CharField(max_length=100, verbose_name="Group Name")
    date_created = models.DateTimeField(auto_now_add=True, verbose_name="Date Created")
    invite_code = models.CharField(max_length=20, unique=True, verbose_name="Invite Code")
    anticheat = models.BooleanField(default=False, verbose_name="Anti-cheat")
    kiosk = models.BooleanField(default=False, verbose_name="Kiosk Mode")

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "Group"
        verbose_name_plural = "Groups"


class GroupMember(models.Model):
    """
    Manages the relationship between users and groups,
    defining the user's role within a specific group.
    """
    RANK_CHOICES = [
        ('ADMIN', 'Admin'),
        ('MEMBER', 'Member'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="members")
    rank = models.CharField(max_length=10, choices=RANK_CHOICES, default='MEMBER', verbose_name="Rank")
    date_joined = models.DateTimeField(auto_now_add=True, verbose_name="Date Joined")

    class Meta:
        # Ensures a user can only be a member of a group once
        unique_together = ('user', 'group')
        verbose_name = "Group Member"
        verbose_name_plural = "Group Members"

    def __str__(self):
        return f"{self.user.username} - {self.group.name} ({self.get_rank_display()})"

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

    class Meta:
        # Ensures that for a given group, grade names are unique (e.g., you can't have two '5' grades)
        unique_together = ('group', 'name')
        verbose_name = "Grade Percentage"
        verbose_name_plural = "Grade Percentages"
        ordering = ['group', '-max_percentage'] # Optional: Orders grades from highest to lowest for each group

    def __str__(self):
        return f"{self.group.name}: {self.name} ({self.min_percentage}% - {self.max_percentage}%)"