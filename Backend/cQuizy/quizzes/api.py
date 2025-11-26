# quizzes/api.py

from typing import List
from collections import defaultdict
from ninja import Router
from ninja.errors import HttpError
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db import transaction

from .models import Quiz, Event, Submission, SubmittedAnswer
from groups.models import GroupMember, Group, Grade, GradePercentage
from blueprints.models import Project, Block
from .schemas import (
    QuizCreateSchema,
    QuizOutSchema,
    QuizContentSchema,
    StudentLockStatusSchema,
    EventCreateSchema,
    EventOutSchema,
    ResolveEventSchema,
    SubmissionCreateSchema,
    SubmissionOutSchema,
    SubmissionDetailSchema,
    PointUpdatePayload
)

from users.auth import JWTAuth

# Apply Auth globally to this router
router = Router(tags=['Quizzes'], auth=JWTAuth())

#! Quiz Endpoints ==================================================
#? Create a new Quiz (Assign Project to Group)
@router.post("/", response=QuizOutSchema, summary="Teacher: Create a new quiz")
def create_quiz(request, payload: QuizCreateSchema):
    """
    Creates a new Quiz session.
    Requires the user to be an ADMIN of the target group.
    """
    current_user = request.auth
    
    # 1. Fetch related objects using IDs from the JSON Payload
    group = get_object_or_404(Group, id=payload.group_id)
    project = get_object_or_404(Project, id=payload.project_id)

    # 2. Authorization Check
    is_admin = GroupMember.objects.filter(
        group=group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "You must be a group admin to assign quizzes.")

    # 3. Create the Quiz
    quiz = Quiz.objects.create(
        group=group,
        project=project,
        date_start=payload.date_start,
        date_end=payload.date_end
    )

    return quiz

#? Get all Quizzes for a Group
@router.get("/group/{group_id}", response=List[QuizOutSchema], summary="List quizzes for a group")
def list_quizzes_for_group(request, group_id: int):
    """
    List all quizzes assigned to a specific group.
    Visible to both Teachers and Students (Members).
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # Authorization: Must be a member of the group
    is_member = GroupMember.objects.filter(group=group, user=current_user).exists()
    
    if not is_member and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    quizzes = Quiz.objects.filter(group=group).select_related('project', 'group')

    return quizzes

#? Start Quiz (Get Questions)
@router.get("/{quiz_id}/start", response=QuizContentSchema, summary="Student: Get questions to start quiz")
def start_quiz(request, quiz_id: int):
    """
    Returns the questions (Blueprints) and settings for the quiz.
    - Security: Strips out 'is_correct' and 'points' from answers via Schema.
    - Validation: Checks if quiz is currently active.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # 1. Authorization: Must be a member
    is_member = GroupMember.objects.filter(group=quiz.group, user=current_user).exists()
    if not is_member and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    # 2. Time Validation (Can only start if active)
    now = timezone.now()
    if now < quiz.date_start:
        raise HttpError(400, "This quiz has not started yet.")
    if now > quiz.date_end:
        raise HttpError(400, "This quiz has ended.")

    # 3. Duplicate Check
    if Submission.objects.filter(quiz=quiz, student=current_user).exists():
        raise HttpError(400, "You have already submitted this quiz.")

    # 4. Return the Quiz Object
    # The Schema resolvers will handle fetching project.blocks and group.anticheat/kiosk
    return quiz


#! Event Handling Endpoints ==================================================
# ? List all Events in the Database
@router.get("/events", response=List[EventOutSchema], summary="Admin: List all events")
def get_all_events(request):
    """ Admin: Get ALL events from the entire database. """
    current_user = request.auth
    
    # Check if user is admin/superuser
    if not current_user.is_superuser:
        raise HttpError(403, "You do not have permission to perform this action.")
    
    events = Event.objects.all().select_related('student')
    
    return events

#? Create/Log an Event
@router.post("/events", response=EventOutSchema, summary="Student: Report a cheat event")
def create_system_event(request, payload: EventCreateSchema):
    """ 
    Student: Create a cheat/log event. 
    Triggered by the Student App when cheating occurs.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=payload.quiz_id)
    
    event = Event.objects.create(
        quiz=quiz,
        student=current_user,
        type=payload.type,
        desc=payload.desc,
        status=Event.Status.ACTIVE
    )
    
    return event


#? Student Polling (Check if unlocked)
@router.get("/{quiz_id}/lock-status", response=StudentLockStatusSchema, summary="Student: Check if currently locked out")
def check_lock_status(request, quiz_id: int):
    """
    Student App polls this every 2-3 seconds while on the 'Locked' screen.
    If 'is_locked' becomes False, the app removes the overlay.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # Check if there is any ACTIVE event for this student in this quiz
    active_event = Event.objects.filter(
        quiz=quiz,
        student=current_user,
        status=Event.Status.ACTIVE
    ).first()

    if active_event:
        return {
            "is_locked": True,
            "active_event_id": active_event.id,
            "message": "Teacher approval required to continue."
        }
    else:
        return {
            "is_locked": False,
            "active_event_id": None,
            "message": "You may continue."
        }

#? List all Events for a Quiz
@router.get("/events/{quiz_id}", response=List[EventOutSchema], summary="Get all events for a specific quiz")
def get_events_for_quiz(request, quiz_id: int):
    """ 
    GET: Treats the ID as a QUIZ ID.
    Returns: A list of all events for that quiz.
    Only available to Group Admins (Teachers).
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # Permission Check: Must be ADMIN of the group
    is_admin = GroupMember.objects.filter(
        group=quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only the teacher can view event logs.")

    events = Event.objects.filter(quiz=quiz).select_related('student')
    
    return events

#? Resolve an Event (by a Teacher)
@router.post("/events/{event_id}", summary="Teacher: Resolve/Unlock an event")
def resolve_event(request, event_id: int, payload: ResolveEventSchema):
    """
    POST: Treats the ID as an EVENT ID.
    Action: Resolves/Unlocks that specific event.
    """
    current_user = request.auth
    event = get_object_or_404(Event, id=event_id)
    
    # Permission Check: Must be ADMIN of the group to resolve
    is_admin = GroupMember.objects.filter(
        group=event.quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "You do not have permission to resolve events for this group.")
    
    event.status = Event.Status.HANDLED
    if payload.note:
        event.note = payload.note
    event.save()
    
    return {"success": True, "new_status": event.status}


#? List all Events for a Quiz (filtered)
@router.get("/events/{quiz_id}/static", response=List[EventOutSchema], summary="Get static logs")
def get_static_events(request, quiz_id: int):
    """ Get logs (non-cheating) for a quiz """
    return _serialize_events(request, quiz_id, Event.Status.STATIC)

@router.get("/events/{quiz_id}/active", response=List[EventOutSchema], summary="Get active alerts")
def get_active_events(request, quiz_id: int):
    """ Get RED ALERT (cheating) events for a quiz """
    return _serialize_events(request, quiz_id, Event.Status.ACTIVE)

@router.get("/events/{quiz_id}/handled", response=List[EventOutSchema], summary="Get resolved history")
def get_handled_events(request, quiz_id: int):
    """ Get RESOLVED events for a quiz """
    return _serialize_events(request, quiz_id, Event.Status.HANDLED)


#! Submission Endpoints ==================================================
#? Submit a Quiz (Auto-Grading & Gradebook Entry)
@router.post("/submit", response=SubmissionOutSchema, summary="Student: Submit quiz and get grade")
def submit_quiz(request, payload: SubmissionCreateSchema):
    """
    Submits a quiz, calculates score using weighted points, saves results, 
    and creates a Grade entry if applicable.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=payload.quiz_id)

    # 1. Validation: Time check
    now = timezone.now()
    if now < quiz.date_start:
        raise HttpError(400, "This quiz has not started yet.")
    if now > quiz.date_end:
        raise HttpError(400, "The submission deadline has passed.")

    if Submission.objects.filter(quiz=quiz, student=current_user).exists():
        raise HttpError(400, "You have already submitted this quiz.")

    # 2. Grading Calculation
    project = quiz.project
    blocks = project.blocks.prefetch_related('answers')
    
    student_answers_map = defaultdict(set)
    for ans in payload.answers:
        student_answers_map[ans.block_id].add(ans.answer_text.strip().lower())

    total_earned_points = 0
    total_max_points = 0
    submitted_answers_to_create = []

    with transaction.atomic():
        # --- A. Calculate Points ---
        for block in blocks:
            # Calculate Max Points for this block
            max_block_points = 0
            block_answers = block.answers.all()
            
            if block.type == Block.BlockType.MULTIPLE_CHOICE:
                 max_block_points = sum(a.points for a in block_answers if a.is_correct and a.points > 0)
            else:
                 # Single Choice or Text: Max is the highest value among correct options
                 correct_opts = [a.points for a in block_answers if a.is_correct]
                 max_block_points = max(correct_opts) if correct_opts else 0
            
            total_max_points += max_block_points

            # Calculate Earned Points
            student_texts = student_answers_map.get(block.id, set())
            answer_lookup = {a.text.strip().lower(): a for a in block_answers}
            
            for text in student_texts:
                points_for_this_answer = 0
                matched_answer = answer_lookup.get(text)
                
                if block.type == Block.BlockType.TEXT_INPUT:
                    if matched_answer and matched_answer.is_correct:
                        points_for_this_answer = matched_answer.points
                else: 
                    # For Checkboxes/Radios, give points if option exists (could be negative)
                    if matched_answer:
                        points_for_this_answer = matched_answer.points
                
                total_earned_points += points_for_this_answer

                submitted_answers_to_create.append({
                    "block": block,
                    "answer_text": text,
                    "points": points_for_this_answer
                })

        # --- B. Calculate Percentage ---
        percentage = (total_earned_points / total_max_points * 100) if total_max_points > 0 else 0.0
        percentage = max(0.0, min(100.0, percentage))

        # --- C. Determine Grade ---
        assigned_grade = None
        
        # Look for a grade range where min <= percentage <= max
        matching_grade_rule = GradePercentage.objects.filter(
            group=quiz.group,
            min__lte=percentage,
            max__gte=percentage,
            is_active=True
        ).first()

        if matching_grade_rule:
            # Automatic Grading: Assign the grade to the Group Admin (Teacher)
            group_admin_member = GroupMember.objects.filter(
                group=quiz.group, 
                rank='ADMIN'
            ).first()

            # Ensure we have a teacher to assign (System requirement)
            if not group_admin_member:
                raise HttpError(500, "Cannot assign grade: Group has no Admin/Teacher.")

            assigned_grade = Grade.objects.create(
                group=quiz.group,
                student=current_user,
                value=matching_grade_rule.name,
                teacher=group_admin_member.user
            )

        # --- D. Save Submission ---
        submission = Submission.objects.create(
            quiz=quiz,
            student=current_user,
            percentage=percentage,
            grade=assigned_grade
        )

        SubmittedAnswer.objects.bulk_create([
            SubmittedAnswer(
                submission=submission,
                block=item['block'],
                answer=item['answer_text'],
                points_awarded=item['points']
            ) for item in submitted_answers_to_create
        ])

    return submission

#? Get Submissions (Results)
@router.get("/{quiz_id}/submissions", response=List[SubmissionOutSchema], summary="Get grades/submissions for a quiz")
def list_submissions(request, quiz_id: int):
    """
    - Teachers (Group Admins): See ALL submissions (the Gradebook).
    - Students: See ONLY their own submission.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # Check permission
    membership = GroupMember.objects.filter(group=quiz.group, user=current_user).first()
    
    if not membership and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    if membership.rank == 'ADMIN' or current_user.is_superuser:
        # Teacher sees everyone
        return Submission.objects.filter(quiz=quiz).select_related('student', 'quiz__project', 'grade')
    else:
        # Student sees only their own
        return Submission.objects.filter(quiz=quiz, student=current_user).select_related('student', 'quiz__project', 'grade')

#? Get Detailed Submission (For Teacher Review)
@router.get("/submission/{submission_id}", response=SubmissionDetailSchema, summary="Teacher: View detailed answers")
def get_submission_detail(request, submission_id: int):
    """
    Returns full details of a submission, including every answer and points awarded.
    """
    current_user = request.auth
    submission = get_object_or_404(Submission, id=submission_id)
    
    # Permission Check: Must be Admin of the group
    is_admin = GroupMember.objects.filter(
        group=submission.quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
         raise HttpError(403, "Only teachers can review detailed submissions.")

    return submission

#? Update Points (Manual Regrading)
@router.post("/submission/{submission_id}/update-points", response=SubmissionOutSchema, summary="Teacher: Update points manually")
def update_submission_points(request, submission_id: int, payload: PointUpdatePayload):
    """
    Teacher modifies points for specific answers.
    System automatically recalculates Percentage and updates the Grade.
    """
    current_user = request.auth
    submission = get_object_or_404(Submission, id=submission_id)
    
    # Permission Check
    is_admin = GroupMember.objects.filter(
        group=submission.quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
         raise HttpError(403, "Only teachers can modify grades.")

    with transaction.atomic():
        # 1. Update the points for specific answers
        total_earned_points = 0
        updates_map = {item.submitted_answer_id: item.new_points for item in payload.updates}
        all_answers = submission.answers.all()
        
        for ans in all_answers:
            if ans.id in updates_map:
                ans.points_awarded = updates_map[ans.id]
                ans.save()
            total_earned_points += ans.points_awarded

        # 2. Recalculate Percentage (Re-calculate Max Points for accuracy)
        project = submission.quiz.project
        blocks = project.blocks.prefetch_related('answers')
        total_max_points = 0
        
        for block in blocks:
            block_answers = block.answers.all()
            if block.type == Block.BlockType.MULTIPLE_CHOICE:
                 total_max_points += sum(a.points for a in block_answers if a.is_correct and a.points > 0)
            else:
                 correct_opts = [a.points for a in block_answers if a.is_correct]
                 total_max_points += max(correct_opts) if correct_opts else 0

        new_percentage = (total_earned_points / total_max_points * 100) if total_max_points > 0 else 0.0
        new_percentage = max(0.0, min(100.0, new_percentage))
        
        submission.percentage = new_percentage
        submission.save()

        # 3. Update the Grade
        if submission.grade:
            matching_grade_rule = GradePercentage.objects.filter(
                group=submission.quiz.group,
                min__lte=new_percentage,
                max__gte=new_percentage,
                is_active=True
            ).first()

            if matching_grade_rule:
                submission.grade.value = matching_grade_rule.name
                submission.grade.teacher = current_user # The teacher manually editing is now responsible
                submission.grade.save()

    return submission


# ! Helper function ==================================================
def _serialize_events(request, quiz_id, status):
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # Permission Check
    is_admin = GroupMember.objects.filter(
        group=quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only the teacher can view event logs.")

    events = Event.objects.filter(
        quiz=quiz, 
        status=status
    ).select_related('student')
    
    return events