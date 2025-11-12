# cQuizy/groups/api.py

from ninja import Router
from django.shortcuts import get_object_or_404
from typing import List
from django.utils import timezone ### CHANGE: Import timezone for setting timestamps

from .models import Group, GroupMember, GradePercentage
from .utils import generate_invite_code
from .schemas import (
    GroupOutSchema,
    GroupWithRankOutSchema,

    MemberOutSchema,

    GroupUpdateSchema,
    GroupTransferSchema,
    GroupCreateSchema,
    GroupJoinSchema,
)

from users.auth import JWTAuth

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Groups'])  # The 'tags' are great for organizing docs

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
        invite_code=invite_code
    )

    # 3. Add the creator as the first admin member
    GroupMember.objects.create(
        group=new_group,
        user=current_user,
        rank='ADMIN'
    )

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
    response_data = []

    ### CHANGE: The logic is now simpler because the default '.objects' manager
    ### automatically filters for active groups and active memberships.
    if current_user.is_superuser:
        # Superusers see all active groups.
        all_groups = Group.objects.all()
        user_memberships = GroupMember.objects.filter(user=current_user)
        membership_ranks = {m.group_id: m.rank for m in user_memberships}

        for group in all_groups:
            actual_rank = membership_ranks.get(group.id)
            response_data.append({
                "id": group.id,
                "name": group.name,
                "date_created": group.date_created,
                "invite_code": group.invite_code,
                "anticheat": group.anticheat,
                "kiosk": group.kiosk,
                "rank": actual_rank if actual_rank else "SUPERUSER"
            })
        return response_data

    # Regular users only see groups where they have an active membership.
    memberships = GroupMember.objects.filter(user=current_user).select_related('group').order_by('date_joined')
    for membership in memberships:
        group = membership.group
        # This check is implicitly handled by the manager, but an explicit check is safest
        if group.date_deleted is None:
            response_data.append({
                "id": group.id,
                "name": group.name,
                "date_created": group.date_created,
                "invite_code": group.invite_code,
                "anticheat": group.anticheat,
                "kiosk": group.kiosk,
                "rank": membership.rank
            })
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
    invite_code = data.invite_code

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
    
    # 2. Generate a new unique code (same logic as create_group)
    while True:
        new_code = generate_invite_code()
        if not Group.objects.filter(invite_code=new_code).exists():
            break
            
    group.invite_code = new_code
    group.save()

    return group

#? Retrieval by ID
@router.get("/{group_id}", response=GroupOutSchema, auth=JWTAuth(), summary="Retrieve a specific group")
def get_group(request, group_id: int):
    """
    Retrieves the details for a single group.

    Access is granted only if the requesting user is an active member or a superuser.
    """
    current_user = request.auth
    
    # 1. Get the active group object from the database.
    group = get_object_or_404(Group, id=group_id)

    # 2. Check for Authorization.
    if current_user.is_superuser:
        return group 

    # 3. If not a superuser, check if they are an active member of the group.
    is_member = GroupMember.objects.filter(group=group, user=current_user).exists()
    
    if is_member:
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
def delete_group(request, group_id: int):
    """
    Soft-deletes a group and all of its current memberships.

    Requires the user to be a superuser or an 'ADMIN' of the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # Authorization Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()

    if not current_user.is_superuser and not is_admin:
        return 403, {"detail": "You do not have permission to delete this group."}

    # If authorized, soft-delete the group.
    ### CHANGE: Replace hard delete with soft delete.
    group.date_deleted = timezone.now()
    group.save()
    
    # Also soft-delete all active memberships in the group.
    current_memberships = GroupMember.objects.filter(group=group)
    for member in current_memberships:
        member.date_left = timezone.now()
        member.left_reason = 'GROUP_DELETED'
        member.save()
    
    return 200, {"success": f"Group '{group.name}' has been deleted."}