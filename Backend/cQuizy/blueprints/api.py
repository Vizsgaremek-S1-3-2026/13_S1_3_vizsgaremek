# cQuizy/blueprints/api.py
# AKA Projects APIs

from ninja import Router
from typing import List
from django.db import transaction
from django.utils import timezone
from django.shortcuts import get_object_or_404

from .models import Project
from .schemas import (
    ProjectCreateSchema,
    ProjectUpdateSchema,
    ProjectOutSchema
)

from users.auth import JWTAuth

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Projects'])  # The 'tags' are great for organizing docs

#! Static Project Handleing Endpoints ==================================================
#? Creation
@router.post("/", response=ProjectOutSchema, auth=JWTAuth())
def create_project(request, payload: ProjectCreateSchema):
    """
    Creates a new Project.
    The user must be authenticated, and the creator is set automatically.
    """

    user = request.auth
    
    project = Project.objects.create(**payload.dict(), creator=user)
    
    return project

#? List Projects
@router.get("/", response=List[ProjectOutSchema], auth=JWTAuth())
def list_projects(request):
    """
    Retrieves a list of all non-deleted projects created by the user.
    """
    user = request.auth
    # We filter for date_deleted__isnull=True to only get active projects
    return Project.objects.filter(creator=user, date_deleted__isnull=True)



#! Resource-specific Group Handleing Endpoints ==================================================
#? Get Project
@router.get("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def get_project_details(request, project_id: int):
    """
    Retrieves the full, nested details of a single project.
    A user can only retrieve a project they created.
    """
    user = request.auth
    # Fetches the project, ensuring it both exists and belongs to the requesting user.
    project = get_object_or_404(Project, id=project_id, creator=user)
    return project

#? Update
@router.put("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def update_full_project(request, project_id: int, payload: ProjectUpdateSchema):
    """
    Intelligently updates a project, handling creates, updates, and deletions
    for nested blocks and answers in a single atomic transaction.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)

    with transaction.atomic():
        # 1. Update top-level Project fields
        project.name = payload.name
        project.desc = payload.desc
        project.save()

        # --- BLOCK PROCESSING ---
        payload_block_ids = {b.id for b in payload.blocks if b.id is not None}
        database_block_ids = set(project.blocks.values_list('id', flat=True))
        
        # 2. Delete blocks that are in the DB but not in the payload
        ids_to_delete = database_block_ids - payload_block_ids
        if ids_to_delete:
            project.blocks.filter(id__in=ids_to_delete).delete()

        # 3. Update existing blocks and create new ones
        for i, block_data in enumerate(payload.blocks):
            if block_data.id: # UPDATE existing block
                block = get_object_or_404(project.blocks, id=block_data.id)
                block.question = block_data.question
                block.type = block_data.type
                block.subtext = block_data.subtext
                block.image_url = block_data.image_url
                block.link_url = block_data.link_url
                block.order = i + 1
                block.save()
            else: # CREATE new block
                block = project.blocks.create(
                    order=i + 1,
                    question=block_data.question,
                    type=block_data.type,
                    subtext=block_data.subtext,
                    image_url=block_data.image_url,
                    link_url=block_data.link_url
                )

            # --- ANSWER PROCESSING (nested inside each block) ---
            payload_answer_ids = {a.id for a in block_data.answers if a.id is not None}
            database_answer_ids = set(block.answers.values_list('id', flat=True))

            # Delete answers for this block
            answer_ids_to_delete = database_answer_ids - payload_answer_ids
            if answer_ids_to_delete:
                block.answers.filter(id__in=answer_ids_to_delete).delete()
            
            # Update and create answers for this block
            for answer_data in block_data.answers:
                if answer_data.id: # UPDATE answer
                    answer = get_object_or_404(block.answers, id=answer_data.id)
                    answer.text = answer_data.text
                    answer.is_correct = answer_data.is_correct
                    answer.save()
                else: # CREATE answer
                    block.answers.create(
                        text=answer_data.text,
                        is_correct=answer_data.is_correct
                    )
    
    # Return the full, updated project object.
    return project

#? Deletion
@router.delete("/{project_id}/", response={204: None}, auth=JWTAuth())
def delete_project(request, project_id: int):
    """
    Soft-deletes a project.
    A user can only delete a project they created.
    """
    # 1. Get the authenticated user
    user = request.auth
    
    # 2. Get the project from the database. If it doesn't exist, this will automatically return a 404 Not Found error. Also check if the user is the creator.
    project = get_object_or_404(Project, id=project_id, creator=user)
        
    # 3. Perform the soft delete by setting the 'date_deleted' field.
    project.date_deleted = timezone.now()
    project.save()
    
    # 4. Return a 204 No Content success response.
    return 204, None