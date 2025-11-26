# quizzes/models.py

from django.db import models
from django.conf import settings

#! Tables ==================================================
#? Quizzes
class Quiz(models.Model):
    """
    Represents a live instance of a quiz (Project) being taken by a Group.
    """

    date_start = models.DateTimeField()

    date_end = models.DateTimeField()
    
    project = models.ForeignKey(
        'blueprints.Project', 
        on_delete=models.CASCADE, 
        related_name='quizzes'
    )
    
    group = models.ForeignKey(
        'groups.Group', 
        on_delete=models.CASCADE, 
        related_name='quizzes'
    )

    class Meta:
        verbose_name = "Quiz"
        verbose_name_plural = "Quizzes"

    def __str__(self):
        return f"Quiz: {self.project} - {self.group}"

#? Events
class Event(models.Model):
    """
    Logs anti-cheat events (e.g., leaving the tab, resizing window).
    """
    class Status(models.TextChoices):
        STATIC = 'STATIC', 'Static'
        ACTIVE = 'ACTIVE', 'Active'
        HANDLED = 'HANDLED', 'Handled'

    date_created = models.DateTimeField(auto_now_add=True)
    
    quiz = models.ForeignKey(
        Quiz, 
        on_delete=models.CASCADE, 
        related_name='events'
    )
    
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='quiz_events'
    )
    
    type = models.CharField(max_length=100)
    
    status = models.CharField(
        max_length=20, 
        choices=Status.choices, 
        default=Status.STATIC
    )
    
    desc = models.TextField()
    
    answer = models.TextField(blank=True, null=True)
    
    note = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.type} - {self.student} ({self.status})"

#? Submissions
class Submission(models.Model):
    """
    Represents the final result of a student's quiz.
    """

    date_submitted = models.DateTimeField(auto_now_add=True)
    
    percentage = models.DecimalField(max_digits=5, decimal_places=2)
    
    quiz = models.ForeignKey(
        Quiz, 
        on_delete=models.CASCADE, 
        related_name='submissions'
    )
    
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='submissions'
    )

    grade = models.ForeignKey(
        'groups.Grade',
        on_delete=models.SET_NULL, # If grade is deleted, keep the submission
        null=True,
        blank=True,
        related_name='submission',
        verbose_name="Associated Grade"
    )

    def __str__(self):
        return f"{self.student} - {self.quiz} ({self.percentage}%)"

#? Submitted Answers
class SubmittedAnswer(models.Model):
    """
    Stores specific answers to questions (Blocks).
    """
    submission = models.ForeignKey(
        Submission, 
        on_delete=models.CASCADE, 
        related_name='answers'
    )
    
    block = models.ForeignKey(
        'blueprints.Block', 
        on_delete=models.CASCADE, 
        related_name='submitted_answers'
    )
    
    answer = models.TextField()
    
    points_awarded = models.IntegerField(
        default=0,
        help_text="The points the student earned for this specific answer."
    )

    def __str__(self):
        return f"Answer to Block {self.block} by {self.submission.student}"