# blueprints/models.py
# AKA Projects

from django.db import models
from django.conf import settings



#! Tables ==================================================
#? Projects
class Project(models.Model):
    """
    Corresponds to the 'projects' table (section 2.6 of the documentation).
    This model stores the templates for tests created by teachers.
    """
    name = models.CharField(max_length=255, verbose_name="Project Name")
    desc = models.TextField(verbose_name="Project Description", blank=True, null=True)
    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="projects",
        verbose_name="Creator"
    )
    date_created = models.DateTimeField(auto_now_add=True, verbose_name="Date Created")
    date_deleted = models.DateTimeField(verbose_name="Date Deleted", blank=True, null=True)

    def __str__(self):
        return f"{self.name} (created by: {self.creator.username})"

    class Meta:
        verbose_name = "Project"
        verbose_name_plural = "Projects"
        ordering = ['-date_created']



#? Blocks
class Block(models.Model):
    """
    Corresponds to the 'blocks' table (section 2.7 of the documentation).
    Represents an individual question or element within a project (test).
    """
    class BlockType(models.TextChoices):
        TEXT_INPUT = 'TEXT', 'Text Input'
        SINGLE_CHOICE = 'SINGLE', 'Single Choice (one correct answer)'
        MULTIPLE_CHOICE = 'MULTIPLE', 'Multiple Choice (several correct answers)'

    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="blocks",
        verbose_name="Project"
    )
    order = models.PositiveIntegerField(verbose_name="Order")
    type = models.CharField(
        max_length=10,
        choices=BlockType.choices,
        default=BlockType.SINGLE_CHOICE,
        verbose_name="Block Type"
    )
    question = models.TextField(verbose_name="Question")
    subtext = models.TextField(verbose_name="Task Description, Information", blank=True, null=True)
    image_url = models.URLField(verbose_name="Optional Image URL", blank=True, null=True)
    link_url = models.URLField(verbose_name="Optional Link URL", blank=True, null=True)

    def __str__(self):
        return f"#{self.order}. Question: {self.question[:50]}... ({self.project.name})"

    class Meta:
        verbose_name = "Block (Question)"
        verbose_name_plural = "Blocks (Questions)"
        unique_together = ('project', 'order')
        ordering = ['project', 'order']



#? Answers
class Answer(models.Model):
    """
    Corresponds to the 'answers' table (section 2.8 of the documentation).
    Stores the possible answer options for a given question (Block).
    """
    block = models.ForeignKey(
        Block,
        on_delete=models.CASCADE,
        related_name="answers",
        verbose_name="Block"
    )
    text = models.TextField(
        verbose_name="Option Text",
        help_text="For text input questions, the correct answer goes here. Otherwise, it can be left empty."
    )
    is_correct = models.BooleanField(
        default=False,
        verbose_name="Is Correct?",
        help_text="Check this if this is a correct answer/option."
    )

    def __str__(self):
        return f"Answer: {self.text[:50]}... (for: {self.block.question[:30]}...)"

    class Meta:
        verbose_name = "Answer (Option)"
        verbose_name_plural = "Answers (Options)"