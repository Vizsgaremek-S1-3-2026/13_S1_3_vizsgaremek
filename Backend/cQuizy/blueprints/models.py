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
    name = models.CharField(max_length=100, verbose_name="Project Name")
    desc = models.TextField(max_length=1000, verbose_name="Project Description", blank=True, null=True)
    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.DO_NOTHING,
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
        TEXT_INPUT = 'text_input', 'Text Input'
        SINGLE_CHOICE = 'single_choice', 'Single Choice (one correct answer)'
        MULTIPLE_CHOICE = 'multiple_choice', 'Multiple Choice (several correct answers)'
        MATCHING = 'matching', 'Matching'
        ORDERING = 'ordering', 'Ordering'
        SENTENCE_ORDERING = 'sentence_ordering', 'Sentence Ordering'
        GAP_FILL = 'gap_fill', 'Gap Fill'
        RANGE = 'range', 'Range'

        TEXT_STATIC = "text_static", "Static Text"
        DIVIDER = "divider", "Divider"


    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="blocks",
        verbose_name="Project"
    )
    order = models.PositiveIntegerField(
        verbose_name="Order"
    )
    type = models.CharField(
        max_length=20,
        choices=BlockType.choices,
        default=BlockType.SINGLE_CHOICE,
        verbose_name="Block Type"
    )
    maintext = models.TextField(
        max_length=1000,
        verbose_name="Question or Value",
        blank=True,
        null=True
    )
    subtext = models.TextField(
        max_length=5000,
        verbose_name="Task Description, Information",
        blank=True,
        null=True
    )
    image_url = models.URLField(
        max_length=2000,
        verbose_name="Optional Image URL",
        blank=True,
        null=True
    )
    link_url = models.URLField(
        max_length=2000,
        verbose_name="Optional Link URL",
        blank=True,
        null=True
    )
    gap_text = models.TextField(
        max_length=5000,
        verbose_name="Gap Text",
        blank=True,
        null=True,
        help_text = "The task itself for Gap Fill blocks."
    )

    def __str__(self):
        return f"#{self.order}. Question: {self.maintext[:50]}... ({self.project.name})"

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
        max_length=500,
        verbose_name="Option Text",
        blank=True, null=True,
        help_text="For text input questions, the correct answer goes here. Otherwise, it can be left empty."
    )
    is_correct = models.BooleanField(
        default=False,
        verbose_name="Is Correct?",
        help_text="Check this if this is a correct answer/option."
    )
    points = models.IntegerField(
        default=1,
        verbose_name="Points",
        help_text="How many points is this answer worth? (Can be 0 or negative for penalties)"
    )
    order = models.PositiveIntegerField(
        default=0,
        verbose_name="Order",
        help_text="The order of this answer in the block."
    )
    match_text = models.TextField(
        max_length=500, 
        verbose_name="Match Pair (Right Side)", 
        blank=True, null=True,
        help_text="Used for Matching type blocks."
    )
    gap_index = models.PositiveIntegerField(
        verbose_name="Gap Index", 
        blank=True, null=True,
        help_text="Used for Gap Fill. Indicates which placeholder {1}, {2} this answer fills."
    )
    numeric_value = models.FloatField(
        verbose_name="Correct Numeric Value", 
        blank=True, null=True,
        help_text="Used for Range/Estimation questions."
    )
    tolerance = models.FloatField(
        verbose_name="Tolerance (+/-)", 
        blank=True, null=True,
        help_text="Used for Range/Estimation. How much deviation is allowed?"
    )
    
    def __str__(self):
        return f"Answer: {self.text[:50]}... (for: {self.block.maintext[:30]}...)"

    class Meta:
        verbose_name = "Answer (Option)"
        verbose_name_plural = "Answers (Options)"
        ordering = ['block', 'order']