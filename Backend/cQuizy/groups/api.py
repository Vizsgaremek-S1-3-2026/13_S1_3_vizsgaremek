import secrets
from ninja import Router
from django.shortcuts import get_object_or_404
from typing import List

from .models import Group, GroupMember, GradePercentage
from .schemas import (
    GroupOutSchema,
    GroupWithRankOutSchema,
    GroupCreateSchema,
    GroupJoinSchema,
)

from users.auth import JWTAuth

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Groups'])  # The 'tags' are great for organizing docs

#! Group Handleing Endpoints ==================================================
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
        invite_code = secrets.token_urlsafe(8) # Generates a URL-safe text string
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

#? Joining
@router.post("/join", response=GroupOutSchema, auth=JWTAuth(), summary="Join a group using an invite code")
def join_group(request, data: GroupJoinSchema):
    """
    Adds the current user to a group if the provided invite_code is valid.
    """
    current_user = request.auth
    invite_code = data.invite_code

    # 1. Find the group with the given invite code.
    # If not found, get_object_or_404 will automatically return a 404 error.
    group = get_object_or_404(Group, invite_code=invite_code)

    # 2. Check if the user is already a member.
    is_already_member = GroupMember.objects.filter(group=group, user=current_user).exists()
    if is_already_member:
        # Return a 400 Bad Request error with a clear message.
        return 400, {"detail": "You are already a member of this group."}

    # 3. If all checks pass, create the membership with the default 'MEMBER' rank.
    GroupMember.objects.create(
        group=group,
        user=current_user,
        rank='MEMBER'
    )

    # Return the data of the group the user just joined.
    return group

#? Retrieval by ID
@router.get("/{group_id}", response=GroupOutSchema, auth=JWTAuth(), summary="Retrieve a specific group")
def get_group(request, group_id: int):
    """
    Retrieves the details for a single group.

    Access is granted only if the requesting user is either:
    1. A superuser.
    2. A member of the group.
    """
    current_user = request.auth
    
    # 1. Get the group object from the database.
    # If a group with this ID doesn't exist, it will automatically
    # return a 404 Not Found error.
    group = get_object_or_404(Group, id=group_id)

    # 2. Check for Authorization.
    # We check for superuser first, as it's a quick and easy pass.
    if current_user.is_superuser:
        return group # Superusers can see everything.

    # 3. If not a superuser, check if they are a member of the group.
    # .exists() is very efficient as it stops at the first match.
    is_member = GroupMember.objects.filter(group=group, user=current_user).exists()
    
    if is_member:
        return group # Group members are allowed to view it.
    
    # 4. If neither check passed, the user is not authorized.
    # We return a 403 Forbidden error with a clear message.
    return 403, {"detail": "You do not have permission to view this group."}

#? Retrieval by listing (all the groups the user has access to)
@router.get("/", response=List[GroupWithRankOutSchema], auth=JWTAuth(), summary="List all groups for the current user")
def list_groups(request):
    """
    Retrieves a list of groups.
    - Regular users see only the groups they are members of.
    - Superusers see ALL groups. Their rank will be their actual rank if they are a member,
      or 'SUPERUSER' if they are not a member but have access due to their status.
    """
    current_user = request.auth
    response_data = []

    if current_user.is_superuser:
        all_groups = Group.objects.all()
        # Get all of the superuser's actual memberships in one efficient query
        user_memberships = GroupMember.objects.filter(user=current_user)
        # Create a dictionary for quick lookups: {group_id: rank}
        membership_ranks = {m.group_id: m.rank for m in user_memberships}

        for group in all_groups:
            # Check if the superuser has an actual membership record for this group
            actual_rank = membership_ranks.get(group.id)

            response_data.append({
                "id": group.id,
                "name": group.name,
                "date_created": group.date_created,
                "invite_code": group.invite_code,
                "anticheat": group.anticheat,
                "kiosk": group.kiosk,
                # Use their real rank if they have one, otherwise assign 'SUPERUSER'
                "rank": actual_rank if actual_rank else "SUPERUSER"
            })
        return response_data

    # This part for regular users remains the same and is correct.
    memberships = GroupMember.objects.filter(user=current_user).select_related('group')
    for membership in memberships:
        group = membership.group
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

#? Leaving
@router.delete("/{group_id}/leave", auth=JWTAuth(), summary="Leave a group")
def leave_group(request, group_id: int):
    """
    Removes the current user from a specific group.

    Prevents the last admin from leaving a group to avoid orphaned groups.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # 1. Find the user's specific membership record for this group.
    # If they are not a member, this will correctly return a 404 Not Found.
    membership = get_object_or_404(GroupMember, group=group, user=current_user)

    # 2. CRITICAL EDGE CASE: Prevent the last admin from leaving.
    if membership.rank == 'ADMIN':
        # Count how many other admins are in the group.
        other_admins_count = GroupMember.objects.filter(group=group, rank='ADMIN').exclude(user=current_user).count()
        if other_admins_count == 0:
            # If there are no other admins, this user cannot leave.
            return 400, {"detail": "You cannot leave the group as you are the only admin. Please transfer ownership or delete the group."}

    # 3. If all checks pass, delete the membership record.
    membership.delete()

    return 200, {"success": f"You have successfully left the group '{group.name}'."}

#? Deletion
@router.delete("/{group_id}", auth=JWTAuth(), summary="Delete a group")
def delete_group(request, group_id: int):
    """
    Deletes a group.

    Requires the user to be a superuser or an 'ADMIN' of the group.
    """
    current_user = request.auth
    group = get_object_or_404(Group, id=group_id)

    # Authorization Check
    is_admin = GroupMember.objects.filter(group=group, user=current_user, rank='ADMIN').exists()

    if not current_user.is_superuser and not is_admin:
        # If they are neither a superuser nor an admin of this group, deny access.
        return 403, {"detail": "You do not have permission to delete this group."}

    # If authorized, delete the group.
    group.delete()
    
    # A successful deletion can return a 204 No Content, but a 200 with a
    # success message is often easier for the frontend to handle.
    return 200, {"success": f"Group '{group.name}' has been deleted."}