# quizzes/api.py

from decimal import Decimal
from typing import List, Dict, Set
from collections import defaultdict
from ninja import Router
from ninja.errors import HttpError
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db import transaction
from django.db.models import Avg, Max, Min, Count

from .models import Quiz, Event, Submission, SubmittedAnswer
from groups.models import GroupMember, Group, Grade, GradePercentage
from blueprints.models import Project, Block, Answer
from .schemas import (
    QuizCreateSchema,
    QuizUpdateSchema,
    QuizOutSchema,
    QuizContentSchema,
    StudentLockStatusSchema,
    EventCreateSchema,
    EventOutSchema,
    ResolveEventSchema,
    SubmissionCreateSchema,
    SubmissionOutSchema,
    SubmissionDetailSchema,
    QuizStatsSchema,
    PointUpdatePayload,
    GradeUpdateSchema,
    QuizStatusOutSchema
)

from users.auth import JWTAuth

# Apply Auth globally to this router
router = Router(tags=['Quizzes'], auth=JWTAuth())

#! Quiz Endpoints ==================================================
#? Create a new quiz
@router.post("/", response=QuizOutSchema, summary="Teacher: Create a new quiz")
def create_quiz(request, payload: QuizCreateSchema):
    """ Creates a new Quiz session. """
    current_user = request.auth
    group = get_object_or_404(Group, id=payload.group_id)
    project = get_object_or_404(Project, id=payload.project_id, date_deleted__isnull=True)

    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "You must be a group admin to assign quizzes.")

    # 3. Logic Validation: End Date must be after Start Date
    if payload.date_end <= payload.date_start:
        raise HttpError(400, "The end date must be after the start date.")

    # 4. Create the Quiz
    quiz = Quiz.objects.create(
        group=group,
        project=project,
        date_start=payload.date_start,
        date_end=payload.date_end
    )
    return quiz

#? Update a quiz
@router.put("/{quiz_id}", response=QuizOutSchema, summary="Teacher: Update a quiz")
def update_quiz(request, quiz_id: int, payload: QuizUpdateSchema):
    """
    Updates an existing Quiz session.
    Constraints: 
    1. Can only DELAY the start date (cannot make it earlier).
    2. End date must be after start date.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    is_admin = GroupMember.objects.filter(group=quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "You must be a group admin to update quizzes.")

    # 2. Logic Validation: Prevent moving date earlier (Only Delay allowed)
    if payload.date_start < quiz.date_start:
        raise HttpError(400, "You cannot make the start date earlier than it currently is. You can only delay it.")

    # 3. Logic Validation: End Date must be after Start Date
    if payload.date_end <= payload.date_start:
        raise HttpError(400, "The end date must be after the start date.")

    # 4. Update the Quiz
    quiz.date_start = payload.date_start
    quiz.date_end = payload.date_end
    quiz.save()
    return quiz

#? Delete Quiz
@router.delete("/{quiz_id}", response={204: None}, summary="Teacher: Delete a pending quiz")
def delete_quiz(request, quiz_id: int):
    """
    Deletes a quiz session.
    Constraint: Can ONLY delete a quiz if it has not started yet.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # 1. Authorization Check (Must be Group Admin)
    is_admin = GroupMember.objects.filter(
        group=quiz.group, 
        user=current_user, 
        rank='ADMIN'
    ).exists()

    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "You must be a group admin to delete quizzes.")

    # 2. Time Validation (Cannot delete if started)
    # If now is greater than or equal to start date, it's too late.
    if timezone.now() >= quiz.date_start:
        raise HttpError(400, "Cannot delete a quiz that has already started.")

    # 3. Perform Deletion
    quiz.delete()
    
    return 204, None

#? Get all Quizzes for a Group
@router.get("/group/{group_id}", response=List[QuizOutSchema], summary="List available quizzes")
def list_quizzes_for_group(request, group_id: int):
    """
    Lists quizzes for a group.
    - Teachers/Admins: See ALL quizzes.
    - Students: See only ACTIVE quizzes they haven't submitted yet.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Check Membership
    membership = GroupMember.objects.filter(group=group, user=current_user).first()
    if not membership and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    # 2. Base Query
    quizzes = Quiz.objects.filter(group=group).select_related('project', 'group')

    # 3. Filter Logic
    # If user is just a MEMBER (student), hide quizzes they already finished
    if not current_user.is_superuser and membership.rank == 'MEMBER':
        # Get IDs of quizzes this student has already submitted
        submitted_quiz_ids = Submission.objects.filter(
            student=current_user, 
            quiz__group=group
        ).values_list('quiz_id', flat=True)
        
        # Exclude those IDs from the list
        quizzes = quizzes.exclude(id__in=submitted_quiz_ids)

    return quizzes

#? Get Student Results
@router.get("/group/{group_id}/results", response=List[SubmissionOutSchema], summary="Student: List past results")
def list_student_results(request, group_id: int):
    """
    Returns a list of PAST submissions for the current user in this group.
    This is the 'History' or 'Grades' tab for the student.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Check Membership
    if not GroupMember.objects.filter(group=group, user=current_user).exists() and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    # 2. Return user's submissions for this group
    return Submission.objects.filter(
        student=current_user, 
        quiz__group=group
    ).select_related('student', 'quiz__project', 'grade').order_by('-date_submitted')

#? Start Quiz
@router.get("/{quiz_id}/start", response=QuizContentSchema, summary="Student: Get questions to start quiz")
def start_quiz(request, quiz_id: int):
    """
    Returns the questions (Blueprints) and settings for the quiz.
    Schema automatically strips sensitive fields (is_correct, points, numeric_value).
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    is_member = GroupMember.objects.filter(group=quiz.group, user=current_user).exists()
    if not is_member and not current_user.is_superuser:
        raise HttpError(403, "You are not a member of this group.")

    now = timezone.now()
    if now < quiz.date_start:
        raise HttpError(400, "This quiz has not started yet.")
    if now > quiz.date_end:
        raise HttpError(400, "This quiz has ended.")

    if Submission.objects.filter(quiz=quiz, student=current_user).exists():
        raise HttpError(400, "You have already submitted this quiz.")

    return quiz


#! Event Handling Endpoints ==================================================
#? Get all Events (for Admins)
@router.get("/events", response=List[EventOutSchema], summary="Admin: List all events")
def get_all_events(request):
    current_user = request.auth
    if not current_user.is_superuser:
        raise HttpError(403, "Permission denied.")
    return Event.objects.all().select_related('student')

#? Report a cheat event
@router.post("/events", response=EventOutSchema, summary="Student: Report a cheat event")
def create_system_event(request, payload: EventCreateSchema):
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

#? Check lock status
@router.get("/{quiz_id}/lock-status", response=StudentLockStatusSchema, summary="Student: Check lock status")
def check_lock_status(request, quiz_id: int):
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    active_event = Event.objects.filter(
        quiz=quiz,
        student=current_user,
        status=Event.Status.ACTIVE
    ).first()

    if active_event:
        return {"is_locked": True, "active_event_id": active_event.id, "message": "Teacher approval required."}
    return {"is_locked": False, "active_event_id": None, "message": "You may continue."}

#? Get quiz events (for Teachers)
@router.get("/events/{quiz_id}", response=List[EventOutSchema], summary="Teacher: Get quiz events")
def get_events_for_quiz(request, quiz_id: int):
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    is_admin = GroupMember.objects.filter(group=quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only the teacher can view event logs.")

    return Event.objects.filter(quiz=quiz).select_related('student')

#? Resolve event
@router.post("/events/{event_id}", summary="Teacher: Resolve event")
def resolve_event(request, event_id: int, payload: ResolveEventSchema):
    current_user = request.auth
    event = get_object_or_404(Event, id=event_id)
    
    is_admin = GroupMember.objects.filter(group=event.quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Permission denied.")
    
    event.status = Event.Status.HANDLED
    if payload.note:
        event.note = payload.note
    event.save()
    return {"success": True, "new_status": event.status}


#! Submission & Grading Endpoints ==================================================
#? Submit Quiz
@router.post("/submit/", response=SubmissionOutSchema, summary="Student: Submit quiz")
def submit_quiz(request, payload: SubmissionCreateSchema):
    """
    Submits a quiz, calculates score, and handles interchangeable words in sentence ordering.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=payload.quiz_id)

    # 1. Validation
    now = timezone.now()
    if now > (quiz.date_end + timezone.timedelta(minutes=2)):
        raise HttpError(400, "Time is up.")

    if Submission.objects.filter(quiz=quiz, student=current_user).exists():
        raise HttpError(400, "You have already submitted this quiz.")

    # 2. Prepare Data
    project = quiz.project
    blocks = project.blocks.all().prefetch_related('answers')
    
    # Map student answers by Block ID for easy lookup
    student_submissions_map = defaultdict(list)
    for ans in payload.answers:
        student_submissions_map[ans.block_id].append(ans)

    total_earned_points = 0.0
    total_max_points = 0.0
    submitted_answers_to_create = []

    # 3. Grading Loop
    with transaction.atomic():
        for block in blocks:
            # Skip static blocks (Descriptions, images, etc.)
            if block.type in ['text_static', 'divider', 'text_block']:
                continue

            block_answers_db = list(block.answers.all())
            student_inputs = student_submissions_map.get(block.id, [])
            
            # --- A. Calculate Max Points (Total possible for this block) ---
            max_points_for_block = 0.0
            
            if block.type == 'multiple_choice':
                max_points_for_block = sum(a.points for a in block_answers_db if a.is_correct and a.points > 0)
            elif block.type in ['single_choice', 'text_input', 'range']:
                # For single choice, max points is the highest value option available
                max_points_for_block = max((a.points for a in block_answers_db), default=1)
            else:
                # Matching, Ordering, Gap Fill, Sentence Ordering: Sum of all parts
                max_points_for_block = sum(a.points for a in block_answers_db)
            
            total_max_points += max_points_for_block

            # --- B. Grade Student Input ---
            points_for_block = 0.0
            
            # Helper to find a specific answer object from DB list by ID
            def get_db_ans(opt_id):
                return next((a for a in block_answers_db if a.id == opt_id), None)

            # 1. CHOICE TYPES
            if block.type in ['single_choice', 'multiple_choice']:
                for inp in student_inputs:
                    if inp.option_id:
                        db_ans = get_db_ans(inp.option_id)
                        if db_ans and db_ans.is_correct:
                            points_for_block += db_ans.points

            # 2. TEXT INPUT
            elif block.type == 'text_input':
                if student_inputs:
                    user_text = (student_inputs[0].answer_text or "").strip().lower()
                    for ans in block_answers_db:
                        if ans.is_correct and ans.text.strip().lower() == user_text:
                            points_for_block = float(ans.points)
                            break 

            # 3. RANGE (Numeric)
            elif block.type == 'range':
                if student_inputs:
                    inp = student_inputs[0]
                    db_ans = block_answers_db[0] if block_answers_db else None
                    if db_ans and db_ans.numeric_value is not None:
                        try:
                            val = float(inp.answer_text)
                            tol = db_ans.tolerance or 0.0
                            if (db_ans.numeric_value - tol) <= val <= (db_ans.numeric_value + tol):
                                points_for_block += db_ans.points
                        except (ValueError, TypeError):
                            pass 

            # 4. MATCHING
            elif block.type == 'matching':
                for inp in student_inputs:
                    if inp.option_id:
                        db_ans = get_db_ans(inp.option_id)
                        if db_ans and db_ans.match_text:
                            user_val = (inp.answer_text or "").strip().lower()
                            correct_val = db_ans.match_text.strip().lower()
                            if user_val == correct_val:
                                points_for_block += db_ans.points

            # 5. ORDERING (Strict ID match usually, but can fall back to text if needed)
            elif block.type == 'ordering':
                sorted_db_answers = sorted(block_answers_db, key=lambda x: x.order)
                for i, inp in enumerate(student_inputs):
                    if i < len(sorted_db_answers):
                        target_ans = sorted_db_answers[i]
                        # Ordering usually relies on specific IDs
                        if inp.option_id == target_ans.id:
                            points_for_block += target_ans.points

            # 6. GAP FILL
            elif block.type == 'gap_fill':
                sorted_db_gaps = sorted(block_answers_db, key=lambda x: x.gap_index or 0)
                for i, inp in enumerate(student_inputs):
                    if i < len(sorted_db_gaps):
                        target_gap = sorted_db_gaps[i]
                        user_val = (inp.answer_text or "").strip().lower()
                        correct_val = (target_gap.text or "").strip().lower()
                        if user_val == correct_val:
                            points_for_block += target_gap.points
            
            # 7. SENTENCE ORDERING (The Fix for Interchangeable Words)
            elif block.type == 'sentence_ordering':
                # Sort correct answer words by their intended order (1, 2, 3...)
                sorted_db_words = sorted(block_answers_db, key=lambda x: x.order)
                
                # Iterate through the student's submitted slots (0, 1, 2...)
                for i, inp in enumerate(student_inputs):
                    if i < len(sorted_db_words):
                        target_word = sorted_db_words[i]
                        
                        # A. Determine what text the student submitted
                        user_val = ""
                        if inp.answer_text:
                            # If frontend sent text directly
                            user_val = inp.answer_text.strip()
                        elif inp.option_id:
                            # If frontend sent an ID, look up the text of that tile
                            # (This handles the "two cats" problem: we get the text of whichever 'cat' tile was used)
                            submitted_tile = get_db_ans(inp.option_id)
                            if submitted_tile:
                                user_val = submitted_tile.text.strip()
                        
                        # B. Compare Text vs Text
                        correct_val = (target_word.text or "").strip()
                        
                        # Case-insensitive comparison for sentence construction? 
                        # Usually sensitive for capitalization, but let's default to sensitive. 
                        # Use .lower() if you want "The" and "the" to match.
                        if user_val == correct_val:
                            points_for_block += target_word.points

            total_earned_points += points_for_block

            # --- C. Create Record for Review (Human Readable Way) ---
            combined_display = []
            for x in student_inputs:
                if x.answer_text and x.answer_text.strip() and block.type != 'matching':
                    combined_display.append(x.answer_text.strip())
                elif x.option_id:
                    db_ans = get_db_ans(x.option_id)
                    if db_ans:
                        if block.type == 'matching' and x.answer_text:
                            combined_display.append(f"{db_ans.text}: {x.answer_text}")
                        else:
                            combined_display.append(db_ans.text)
                    else:
                        combined_display.append(f"[ID:{x.option_id}]")

            if block.type in ['ordering', 'sentence_ordering']:
                display_string = " → ".join(combined_display)
            else:
                display_string = ", ".join(combined_display)

            submitted_answers_to_create.append({
                "block": block,
                "answer_text": display_string,
                "points": int(points_for_block)
            })

        # --- D. Finalize Submission ---
        # Calculate Percentage using the newly calculated max_points
        if total_max_points > 0:
            raw_percentage = (total_earned_points / total_max_points) * 100
        else:
            raw_percentage = 0.0
        
        percentage = Decimal(min(100.0, max(0.0, raw_percentage)))

        # Find Grade
        assigned_grade = None
        grade_rule = GradePercentage.objects.filter(
            group=quiz.group,
            min_percentage__lte=percentage,
            max_percentage__gte=percentage,
            is_active=True
        ).first()

        if grade_rule:
            admin_member = GroupMember.objects.filter(group=quiz.group, rank='ADMIN').first()
            teacher_user = admin_member.user if admin_member else current_user
            assigned_grade = Grade.objects.create(
                group=quiz.group,
                student=current_user,
                value=grade_rule.name,
                teacher=teacher_user
            )

        # Create Submission with Score and Max Score
        submission = Submission.objects.create(
            quiz=quiz,
            student=current_user,
            percentage=percentage,
            score=total_earned_points,  # <--- Saved!
            max_score=total_max_points, # <--- Saved!
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

#? Get grades
@router.get("/{quiz_id}/submissions", response=List[SubmissionOutSchema], summary="Get grades")
def list_submissions(request, quiz_id: int):
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)
    membership = GroupMember.objects.filter(group=quiz.group, user=current_user).first()
    
    if not membership and not current_user.is_superuser:
        raise HttpError(403, "Permission denied.")

    if membership.rank == 'ADMIN' or current_user.is_superuser:
        return Submission.objects.filter(quiz=quiz).select_related('student', 'quiz__project', 'grade')
    else:
        return Submission.objects.filter(quiz=quiz, student=current_user).select_related('student', 'quiz__project', 'grade')

#? Get submission details
@router.get("/submission/{submission_id}", response=SubmissionDetailSchema, summary="Review submission details")
def get_submission_detail(request, submission_id: int):
    """
    Retrieves the detailed answers of a submission.
    Allowed for:
    1. Group Admins (Teachers)
    2. The Student who owns the submission (to review mistakes)
    """
    current_user = request.auth
    submission = get_object_or_404(Submission, id=submission_id)
    
    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=submission.quiz.group, user=current_user, rank='ADMIN').exists()
    is_owner = (submission.student == current_user)

    if not is_admin and not is_owner and not current_user.is_superuser:
         raise HttpError(403, "Permission denied. You cannot view this submission.")

    return submission

#? Get statistics
@router.get("/{quiz_id}/stats", response=QuizStatsSchema, summary="Get statistics")
def get_quiz_stats(request, quiz_id: int):
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)
    is_member = GroupMember.objects.filter(group=quiz.group, user=current_user).exists()
    if not is_member and not current_user.is_superuser:
        raise HttpError(403, "Permission denied.")

    stats = Submission.objects.filter(quiz=quiz).aggregate(
        average_score=Avg('percentage'),
        max_score=Max('percentage'),
        min_score=Min('percentage'),
        submission_count=Count('id')
    )
    return {
        "average_score": stats['average_score'] or 0.0,
        "max_score": stats['max_score'] or 0.0,
        "min_score": stats['min_score'] or 0.0,
        "submission_count": stats['submission_count'] or 0
    }

#? Get quiz live status
@router.get("/{quiz_id}/status", response=QuizStatusOutSchema, summary="Teacher: Get live quiz status of students")
def get_quiz_status(request, quiz_id: int):
    """
    Returns lists of students in the quiz grouped by their current status:
    - writing: Currently taking the quiz (haven't submitted, not locked).
    - locked: Locked out due to an active anti-cheat event.
    - finished: Successfully submitted the quiz.
    """
    current_user = request.auth
    quiz = get_object_or_404(Quiz, id=quiz_id)

    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Permission denied. Only teachers can view the live status.")

    # 2. Gather student groups
    members = GroupMember.objects.filter(group=quiz.group, rank='MEMBER').select_related('user')
    
    finished_ids = set(Submission.objects.filter(quiz=quiz).values_list('student_id', flat=True))
    locked_ids = set(Event.objects.filter(quiz=quiz, status=Event.Status.ACTIVE).values_list('student_id', flat=True))

    writing = []
    locked = []
    finished = []

    for member in members:
        user_data = {"id": member.user.id, "username": member.user.username}
        if member.user.id in finished_ids:
            finished.append(user_data)
        elif member.user.id in locked_ids:
            locked.append(user_data)
        else:
            writing.append(user_data)

    return {
        "writing": writing,
        "locked": locked,
        "finished": finished
    }

#? Update points
@router.post("/submission/{submission_id}/update-points", response=SubmissionOutSchema, summary="Teacher: Manual regrade")
def update_submission_points(request, submission_id: int, payload: PointUpdatePayload):
    """
    Updates points for specific questions and recalculates the final grade
    based on the stored max_score.
    """
    current_user = request.auth
    submission = get_object_or_404(Submission, id=submission_id)
    
    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=submission.quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
         raise HttpError(403, "Permission denied.")

    with transaction.atomic():
        # 2. Update the specific answers
        updates_map = {item.submitted_answer_id: item.new_points for item in payload.updates}
        
        # Fetch all answers to recalculate the TOTAL score
        # (We iterate all of them to ensure the total sum is 100% correct)
        all_answers = submission.answers.all()
        
        total_new_score = 0.0
        
        for ans in all_answers:
            if ans.id in updates_map:
                # Update the DB record with the teacher's manual override
                ans.points_awarded = updates_map[ans.id]
                ans.save()
            
            # Add to the running total (converting to float for math)
            total_new_score += float(ans.points_awarded)

        # 3. Update the Submission totals
        submission.score = total_new_score
        
        # Use the stored max_score to calculate percentage
        if submission.max_score > 0:
            submission.percentage = (Decimal(total_new_score) / submission.max_score) * 100
        else:
            submission.percentage = 0.0
            
        # Clamp percentage 0-100 just in case
        submission.percentage = min(100.0, max(0.0, float(submission.percentage)))

        # 4. Update the Linked Grade Logic
        # If the score changed, the grade (e.g., "5" or "A") might need to change.
        new_grade_rule = GradePercentage.objects.filter(
            group=submission.quiz.group,
            min_percentage__lte=submission.percentage,
            max_percentage__gte=submission.percentage,
            is_active=True
        ).first()

        if submission.grade and new_grade_rule:
            # If a grade exists and the rule says it should be different now
            if submission.grade.value != new_grade_rule.name:
                submission.grade.value = new_grade_rule.name
                submission.grade.save()
        elif not submission.grade and new_grade_rule:
            # If there was no grade before (e.g. 0%), but now there is
            submission.grade = Grade.objects.create(
                group=submission.quiz.group,
                student=submission.student,
                value=new_grade_rule.name,
                teacher=current_user 
            )

        submission.save()

    return submission

#? Update grade
@router.post("/submission/{submission_id}/update-grade", response=SubmissionOutSchema)
def update_submission_grade(request, submission_id: int, payload: GradeUpdateSchema):
    current_user = request.auth
    submission = get_object_or_404(Submission, id=submission_id)
    
    is_admin = GroupMember.objects.filter(group=submission.quiz.group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
         raise HttpError(403, "Permission denied.")

    if submission.grade:
        submission.grade.value = payload.new_grade
        submission.grade.teacher = current_user
        submission.grade.save()
    else:
        submission.grade = Grade.objects.create(
            group=submission.quiz.group,
            student=submission.student,
            value=payload.new_grade,
            teacher=current_user
        )
        submission.save()
    return submission