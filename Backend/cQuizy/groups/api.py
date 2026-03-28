# cQuizy/groups/api.py

from ninja import Router
from django.shortcuts import get_object_or_404
from typing import List
from django.utils import timezone
from django.db import transaction
from django.db.models import Avg, Count

from .models import Group, GroupMember, GradePercentage
from quizzes.models import Submission, Quiz
from .utils import generate_invite_code
from .schemas import (
    GroupOutSchema,
    GroupWithRankOutSchema,

    MemberOutSchema,

    GroupUpdateSchema,
    GroupTransferSchema,
    GroupCreateSchema,
    GroupJoinSchema,
    GroupDeleteSchema,

    GradePercentageSchema,
    GradePercentageListSchema,

    AdminGroupOverviewSchema,
    AdminStudentStatSchema,
    AdminQuizStatSchema,
)

from users.auth import JWTAuth

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Groups'])  # The 'tags' are great for organizing docs



#! Helper Functions
#? Get grade label
def get_grade_label(percentage: float, rules: list) -> str:
    """
    Takes a percentage and a list of GradePercentage objects.
    Returns the name of the grade (e.g., '5', 'A', 'Excellent').
    """
    if percentage is None:
        return "N/A"
    
    # Iterate through rules to find the match
    # Rules should be passed in sorted order for efficiency, but logic holds regardless
    for rule in rules:
        if rule.min_percentage <= percentage <= rule.max_percentage:
            return rule.name
    
    return "-" # No matching grade found



#! Static Group Handleing Endpoints ==================================================
#? Creation
@router.post("/", response=GroupOutSchema, auth=JWTAuth(), summary="Create a new group")
def create_group(request, data: GroupCreateSchema):
    """
    Creates a new group. The authenticated user making the request
    automatically becomes the first 'ADMIN' of the group.
    """
    # request.auth is now populated by your JWTAuth class
    current_user = request.auth

    # 1. Generate a unique invite code
    while True:
        invite_code = generate_invite_code()
        if not Group.objects.filter(invite_code=invite_code).exists():
            break

    # 2. Create the Group instance
    new_group = Group.objects.create(
        name=data.name,
        color=data.color,
        invite_code=invite_code
    )

    # 3. Add the creator as the first admin member
    GroupMember.objects.create(
        group=new_group,
        user=current_user,
        rank='ADMIN'
    )

    new_group.rank = 'ADMIN'

    return new_group

#? Retrieval by listing (all the groups the user has access to)
@router.get("/", response=List[GroupWithRankOutSchema], auth=JWTAuth(), summary="List all groups for the current user")
def list_groups(request):
    """
    Retrieves a list of active groups.
    - Regular users see only the active groups they are active members of.
    - Superusers see ALL active groups.
    """
    current_user = request.auth
    
    ### CHANGE: The logic is now simpler because the default '.objects' manager
    ### automatically filters for active groups and active memberships.
    if current_user.is_superuser:
        # Superusers see all active groups.
        all_groups = Group.objects.all()
        user_memberships = GroupMember.objects.filter(user=current_user)
        membership_ranks = {m.group_id: m.rank for m in user_memberships}

        # Instead of returning a list of dicts, we can return the queryset directly
        # and let Ninja handle the serialization with the schema. This is cleaner.
        response_data = []
        for group in all_groups:
            actual_rank = membership_ranks.get(group.id)
            # By adding the rank to the group object itself, we can pass the object
            # to the schema, which will correctly serialize everything.
            group.rank = actual_rank if actual_rank else "SUPERUSER"
            response_data.append(group)
        return response_data

    # Regular users only see groups where they have an active membership.
    memberships = GroupMember.objects.filter(user=current_user).select_related('group').order_by('date_joined')
    
    response_data = []
    for membership in memberships:
        group = membership.group
        # This check is implicitly handled by the manager, but an explicit check is safest
        if group.date_deleted is None:
            # Similar to the superuser case, add the rank to the group object.
            group.rank = membership.rank
            response_data.append(group)
    
    return response_data

#? Joining
@router.post("/join", response=GroupOutSchema, auth=JWTAuth(), summary="Join a group using an invite code")
def join_group(request, data: GroupJoinSchema):
    """
    Adds the current user to a group using an invite code.

    - If the user has never been in the group, it creates a new membership record.
    - If the user was previously in the group and left (i.e., their membership was
      soft-deleted), this will reactivate their existing membership, preserving
      their original join date.
    - If the user is already an active member, it returns an error.
    """
    current_user = request.auth
    raw_invite_code = data.invite_code
    invite_code = raw_invite_code.replace('-', '')

    # 1. Find the group with the given invite code.
    # The default manager 'Group.objects' automatically ensures we only find
    # an active (not deleted) group.
    group = get_object_or_404(Group, invite_code=invite_code)

    # 2. Look for an existing membership record, including inactive ones.
    # We use 'GroupMember.all_objects' to search through ALL historical records.
    membership, created = GroupMember.all_objects.get_or_create(
        group=group,
        user=current_user,
        defaults={'rank': 'MEMBER'}
    )

    # 3. Handle the outcome.
    if not created:
        # A membership record for this user and group already existed.
        if membership.date_left is not None:
            # The existing record was inactive (soft-deleted). Reactivate it.
            membership.date_left = None
            membership.left_reason = None
            membership.save()
        else:
            # The existing record is already active.
            return 400, {"detail": "You are already an active member of this group."}

    # 4. Return the data of the group the user just joined.
    return group

#! Resource-specific Group Handleing Endpoints ==================================================
#? Kicking a Member
@router.delete("/{group_id}/members/{user_id}", auth=JWTAuth(), summary="Remove (kick) a member from a group")
def kick_member(request, group_id: int, user_id: int):
    """
    Soft-deletes a member from a group.
    
    - Requires the requesting user to be an ADMIN of the group.
    - An admin cannot kick themselves.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Authorization: The '.objects' manager ensures we check for an *active* membership.
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        return 403, {"detail": "You do not have permission to perform this action."}
        
    # 2. Edge Case: Prevent kicking yourself. They should use the "leave" endpoint.
    if current_user.id == user_id:
        return 400, {"detail": "You cannot kick yourself. Please use the 'leave group' endpoint."}

    # 3. Find the target member's active record.
    member_to_kick = get_object_or_404(GroupMember, group=group, user_id=user_id)
    
    ### CHANGE: Replace hard delete with soft delete.
    member_to_kick.date_left = timezone.now()
    member_to_kick.left_reason = 'KICKED'
    member_to_kick.save()

    return 200, {"success": "Member has been removed from the group."}

#? List Group Members
@router.get("/{group_id}/members", response=List[MemberOutSchema], auth=JWTAuth(), summary="List all members of a group")
def list_members(request, group_id: int):
    """
    Retrieves a list of all *active* members in a specific group.
    
    Requires the user to be a member of the group to view the list.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Authorization Check: Is the user an active member of this group?
    is_member = GroupMember.objects.filter(group=group, user=current_user).exists()
    if not is_member and not current_user.is_superuser:
        return 403, {"detail": "You do not have permission to view this group's members."}

    # 2. Fetch all members.
    ### CHANGE: The default '.objects' manager automatically returns only active members.
    members = GroupMember.objects.filter(group=group) \
        .select_related('user') \
        .order_by('rank', 'date_joined')
    
    return members

#? Transfer Ownership
@router.post("/{group_id}/transfer", auth=JWTAuth(), summary="Transfer ownership of a group")
def transfer(request, group_id: int, data: GroupTransferSchema):
    """
    Transfers the ownership of a group to another member.

    - The user making the request must be an 'ADMIN'.
    - The target user must be an active member of the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)
    new_owner_id = data.user_id

    # 1. Authorization Check: Get the current admin's active membership.
    current_admin_membership = get_object_or_404(GroupMember, group=group, user=current_user, rank='ADMIN')

    # 2. Find the target user's active membership.
    new_owner_membership = get_object_or_404(GroupMember, group=group, user_id=new_owner_id)

    # 3. Prevent transferring ownership to oneself
    if current_user.id == new_owner_id:
        return 400, {"detail": "You are already the owner of this group."}

    # 4. Perform the transfer
    current_admin_membership.rank = 'MEMBER'
    current_admin_membership.save()

    new_owner_membership.rank = 'ADMIN'
    new_owner_membership.save()

    return 200, {"success": f"Ownership of '{group.name}' has been transferred."}

#? Leaving
@router.delete("/{group_id}/leave", auth=JWTAuth(), summary="Leave a group")
def leave_group(request, group_id: int):
    """
    Soft-deletes the current user's membership in a group.

    Prevents the last admin from leaving a group to avoid orphaned groups.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Find the user's active membership record for this group.
    membership = get_object_or_404(GroupMember, group=group, user=current_user)

    # 2. CRITICAL EDGE CASE: Prevent the last admin from leaving.
    if membership.rank == 'ADMIN':
        # Count how many other *active* admins are in the group.
        other_admins_count = GroupMember.objects.filter(group=group, rank='ADMIN').exclude(user=current_user).count()
        if other_admins_count == 0:
            return 400, {"detail": "You cannot leave as the only admin. Please transfer ownership or delete the group."}

    # 3. If all checks pass, soft-delete the membership record.
    ### CHANGE: Replace hard delete with soft delete.
    membership.date_left = timezone.now()
    membership.left_reason = 'LEFT'
    membership.save()

    return 200, {"success": f"You have successfully left the group '{group.name}'."}

#? Regenerate Invite Code
@router.post("/{group_id}/regenerate-invite", response=GroupOutSchema, auth=JWTAuth(), summary="Regenerate the group's invite code")
def regenerate_invite_code(request, group_id: int):
    """
    Generates a new, unique invite code for the group, invalidating the old one.
    
    Requires the user to be an ADMIN of the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Authorization Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        return 403, {"detail": "You do not have permission to perform this action."}
    
    group.rank = "SUPERUSER" if current_user.is_superuser else "ADMIN"
    
    # 2. Generate a new unique code (same logic as create_group)
    while True:
        new_code = generate_invite_code()
        if not Group.objects.filter(invite_code=new_code).exists():
            break
            
    group.invite_code = new_code
    group.save()

    return group

#? Retrieval by ID
@router.get("/{group_id}", response=GroupWithRankOutSchema, auth=JWTAuth(), summary="Retrieve a specific group")
def get_group(request, group_id: int):
    """
    Retrieves the details for a single group, INCLUDING the user's rank.
    """
    current_user = request.auth
    
    # 1. Get the active group
    group = get_object_or_404(Group, id=group_id)

    # 2. Check for Authorization and determine Rank
    if current_user.is_superuser:
        group.rank = "SUPERUSER" # Manually attach rank for the schema
        return group 

    # 3. Check membership
    # We use 'first()' so we get the object to access .rank
    membership = GroupMember.objects.filter(group=group, user=current_user).first()
    
    if membership:
        group.rank = membership.rank # Manually attach rank for the schema
        return group
    
    return 403, {"detail": "You do not have permission to view this group."}

#? Change Group Data (Including Renaming)
@router.patch("/{group_id}", response=GroupOutSchema, auth=JWTAuth(), summary="Update a group's settings")
def update_group_settings(request, group_id: int, payload: GroupUpdateSchema):
    """
    Updates a group's settings (name, anticheat, kiosk).
    
    Requires the user to be an ADMIN of the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Authorization Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        return 403, {"detail": "You do not have permission to modify this group."}

    group.rank = "SUPERUSER" if current_user.is_superuser else "ADMIN"

    # 2. Get the data the client actually sent
    update_data = payload.dict(exclude_none=True)

    # 3. Update the group object and save
    if not update_data:
        return 200, group

    for key, value in update_data.items():
        setattr(group, key, value)
    
    group.save()
    
    return group

#? Deletion
@router.delete("/{group_id}", auth=JWTAuth(), summary="Delete a group")
def delete_group(request, group_id: int, payload: GroupDeleteSchema): # <--- Add payload argument
    """
    Soft-deletes a group and all of its current memberships.
    Requires password confirmation.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Authorization Check (Check this FIRST to prevent unauthorized password guessing)
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()

    if not current_user.is_superuser and not is_admin:
        return 403, {"detail": "You do not have permission to delete this group."}

    # 2. Password Confirmation
    # The 'check_password' method handles the hashing comparison securely
    if not current_user.check_password(payload.password):
        return 403, {"detail": "Invalid password. Group deletion canceled."}

    # 3. Soft-delete the group
    group.date_deleted = timezone.now()
    group.save()
    
    # 4. Soft-delete all active memberships
    current_memberships = GroupMember.objects.filter(group=group)
    for member in current_memberships:
        member.date_left = timezone.now()
        member.left_reason = 'GROUP_DELETED'
        member.save()
    
    return 200, {"success": f"Group '{group.name}' has been deleted."}



#! Grading Endpoints
#? Getting the grading scale
@router.get("/{group_id}/grading-scale", response=List[GradePercentageSchema], auth=JWTAuth(), summary="Get grading scale")
def get_grading_scale(request, group_id: int):
    """
    Returns the active grading scale for the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Auth Check: User must be at least a member
    if not GroupMember.objects.filter(group=group, user=current_user).exists() and not current_user.is_superuser:
        return 403, {"detail": "You do not have permission to view this group."}

    # 2. Return active percentages
    # We filter is_active=True in case you implement soft-delete for these later
    return GradePercentage.objects.filter(group=group, is_active=True).order_by('-max_percentage')

#? Creating/Updating the grading scale
@router.put("/{group_id}/grading-scale", response=List[GradePercentageSchema], auth=JWTAuth(), summary="Update grading scale")
def update_grading_scale(request, group_id: int, payload: GradePercentageListSchema):
    """
    Replaces the ENTIRE grading scale for the group with the new list provided.
    
    Logic:
    1. Validates user is Admin.
    2. Validates that percentages don't overlap (optional but recommended).
    3. Deletes old active scales and creates new ones.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Auth Check: Admin only
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        return 403, {"detail": "Only admins can configure the grading scale."}

    new_grades_data = payload.grades

    # 2. Optional: Check for overlaps (Basic logic)
    # Sort by min percentage to make checking easier
    sorted_grades = sorted(new_grades_data, key=lambda x: x.min_percentage)
    for i in range(len(sorted_grades) - 1):
        current_grade = sorted_grades[i]
        next_grade = sorted_grades[i+1]
        
        # If the max of the current overlaps with the min of the next
        if current_grade.max_percentage > next_grade.min_percentage:
             return 400, {
                 "detail": f"Overlap detected between '{current_grade.name}' and '{next_grade.name}'."
             }

    # 3. Atomic Update (Delete old, Insert new)
    with transaction.atomic():
        # Soft delete or Hard delete existing active grades? 
        # Since this is a configuration setting, Hard Delete (or deactivating) the old ones 
        # and creating new ones is usually the cleanest approach for a "Replace" operation.
        
        # Option A: Hard Delete old configs to keep DB clean
        GradePercentage.objects.filter(group=group).delete()
        
        # Option B: Soft Delete (Set is_active=False)
        # GradePercentage.objects.filter(group=group).update(is_active=False)

        # Create new ones
        new_objects = [
            GradePercentage(
                group=group,
                name=g.name,
                min_percentage=g.min_percentage,
                max_percentage=g.max_percentage,
                is_active=True
            ) for g in new_grades_data
        ]
        
        GradePercentage.objects.bulk_create(new_objects)

    # Return the newly created objects
    return GradePercentage.objects.filter(group=group, is_active=True).order_by('-max_percentage')



#! Admin Statistics Endpoints ==================================================
#? Stats Overview
@router.get("/{group_id}/stats/overview", response=AdminGroupOverviewSchema, auth=JWTAuth())
def get_group_overview(request, group_id: int):
    """
    Returns the 'Big Picture': Class average percentage and the resulting Grade.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only admins can view statistics.")

    # 2. Fetch Grading Rules (Active only)
    rules = list(GradePercentage.objects.filter(group=group, is_active=True))

    # 3. Calculate Global Average
    stats = Submission.objects.filter(quiz__group=group).aggregate(
        avg=Avg('percentage')
    )
    avg_pct = stats['avg'] or 0.0

    # 4. Get Counts
    student_count = GroupMember.objects.filter(group=group, date_left__isnull=True).count()
    quiz_count = Quiz.objects.filter(group=group).count()

    return {
        "average_percentage": round(avg_pct, 2),
        "average_grade_label": get_grade_label(avg_pct, rules),
        "total_students": student_count,
        "total_quizzes": quiz_count
    }

#? Stats Student Avarage
@router.get("/{group_id}/stats/students", response=List[AdminStudentStatSchema], auth=JWTAuth())
def get_student_averages(request, group_id: int):
    """
    Returns a list of students with their individual average + Grade Label.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only admins can view statistics.")

    # 2. Fetch Rules
    rules = list(GradePercentage.objects.filter(group=group, is_active=True))

    # 3. Get Members
    members = GroupMember.objects.filter(group=group, date_left__isnull=True).select_related('user')

    results = []
    for member in members:
        # Calculate specific student average
        # (Optimized: In a massive scale app, we'd use annotations, but this is fine for standard classes)
        student_avg = Submission.objects.filter(
            quiz__group=group, 
            student=member.user
        ).aggregate(avg=Avg('percentage'))['avg']
        
        final_avg = student_avg or 0.0

        results.append({
            "student_id": member.user.id,
            "name": f"{member.user.last_name} {member.user.first_name}", # Hungarian name order?
            "average_percentage": round(final_avg, 2),
            "average_grade_label": get_grade_label(final_avg, rules)
        })

    # Sort by average (High to Low)
    return sorted(results, key=lambda x: x['average_percentage'], reverse=True)

#? Stats Quiz Avarage
@router.get("/{group_id}/stats/quizzes", response=List[AdminQuizStatSchema], auth=JWTAuth())
def get_quiz_averages(request, group_id: int):
    """
    Returns a list of quizzes with their average + Grade Label.
    Helps identifying which tests were "Killer tests" (hard) vs "Easy A's".
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Auth Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()
    if not is_admin and not current_user.is_superuser:
        raise HttpError(403, "Only admins can view statistics.")

    # 2. Fetch Rules
    rules = list(GradePercentage.objects.filter(group=group, is_active=True))

    # 3. Get Quizzes
    quizzes = Quiz.objects.filter(group=group).select_related('project').order_by('-date_end')

    results = []
    for quiz in quizzes:
        stats = Submission.objects.filter(quiz=quiz).aggregate(
            avg=Avg('percentage'),
            count=Count('id')
        )
        final_avg = stats['avg'] or 0.0
        
        results.append({
            "quiz_id": quiz.id,
            "quiz_name": quiz.project.name,
            "date": quiz.date_end,
            "average_percentage": round(final_avg, 2),
            "average_grade_label": get_grade_label(final_avg, rules),
            "submission_count": stats['count']
        })

    return results