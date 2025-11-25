# cQuizy/blueprints/api.py
# AKA Projects APIs

from ninja import Router
from typing import List, Optional
from django.db import transaction
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db.models import Q

from .models import Project, Block
from .schemas import (
    ProjectCreateSchema,
    ProjectUpdateSchema,
    ProjectOutSchema,
    BlockOutSchema
)

from users.auth import JWTAuth

# Instead of using NinjaAPI, we use Router for app-specific endpoints
router = Router(tags=['Projects'])

#? Creation
@router.post("/", response=ProjectOutSchema, auth=JWTAuth())
def create_project(request, payload: ProjectCreateSchema):
    """
    Creates a new, empty Project.
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
    return Project.objects.filter(creator=user, date_deleted__isnull=True)

#? Search User's Blocks
@router.get("/my-blocks/", response=List[BlockOutSchema], auth=JWTAuth())
def search_user_blocks(request, query: Optional[str] = None, mode: str = 'both'):
    """
    Searches for blocks (questions) within projects created by the authenticated user.
    Used for the 'Insert Existing Question' feature.
    Modes: 'question', 'answer', 'both'.
    """
    user = request.auth
    
    # 1. Base filter: User's blocks from non-deleted projects
    blocks_qs = Block.objects.filter(
        project__creator=user, 
        project__date_deleted__isnull=True
    ).select_related('project').prefetch_related('answers')

    # 2. Apply search logic based on mode and query
    if query and query.strip():
        if mode == 'question':
            blocks_qs = blocks_qs.filter(
                Q(question__icontains=query) | 
                Q(subtext__icontains=query)
            )
        elif mode == 'answer':
            blocks_qs = blocks_qs.filter(
                answers__text__icontains=query
            )
        else: # 'both'
            blocks_qs = blocks_qs.filter(
                Q(question__icontains=query) | 
                Q(subtext__icontains=query) |
                Q(answers__text__icontains=query)
            )
    
    # 3. distinct() is required because filtering by 'answers' (many-to-many)
    # can return the same block multiple times.
    # Limit results to 20.
    blocks_qs = blocks_qs.distinct()[:20]

    return blocks_qs

#? Retrieve Project
@router.get("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def get_project_details(request, project_id: int):
    """
    Retrieves full, nested details of a single project created by the user.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)
    return project

#? Update Project
@router.put("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def update_full_project(request, project_id: int, payload: ProjectUpdateSchema):
    """
    Intelligently updates a project, validating all business rules (limits, question types, empty values)
    before saving.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)

    # --- FULL VALIDATION BLOCK ---

    if not payload.name or not payload.name.strip():
        return 400, {"detail": "Project name cannot be empty."}
    if len(payload.blocks) > 100:
        return 400, {"detail": "A project cannot have more than 100 questions."}

    for i, block_data in enumerate(payload.blocks):
        question_num = i + 1

        if not block_data.question or not block_data.question.strip():
            return 400, {"detail": f"Question #{question_num} cannot be empty."}
        
        # Minimum 2 answers rule for multiple-choice questions
        if block_data.type in ['SINGLE', 'MULTIPLE'] and len(block_data.answers) < 2:
            return 400, {"detail": f"Question #{question_num} ('{block_data.question[:20]}...') must have at least two answers."}

        if len(block_data.answers) > 10:
            return 400, {"detail": f"Question #{question_num} ('{block_data.question[:20]}...') cannot have more than 10 answers."}
        
        for j, answer_data in enumerate(block_data.answers):
            answer_num = j + 1
            if not answer_data.text or not answer_data.text.strip():
                return 400, {"detail": f"At Question #{question_num}, answer #{answer_num} cannot be empty."}

        if block_data.type == 'SINGLE':
            correct_answers_count = sum(1 for answer in block_data.answers if answer.is_correct)
            if correct_answers_count > 1:
                return 400, {"detail": f"Question #{question_num} ('{block_data.question[:20]}...') can only have one correct answer."}
        if block_data.type == 'TEXT':
            if any(not answer.is_correct for answer in block_data.answers):
                return 400, {"detail": f"Question #{question_num} ('{block_data.question[:20]}...') is a text question but has an answer marked as incorrect."}

    with transaction.atomic():
        project.name = payload.name
        project.desc = payload.desc.strip() if payload.desc else None # Converts empty string to None
        project.save()

        payload_block_ids = {b.id for b in payload.blocks if b.id is not None}
        block_map = {b.id: b for b in project.blocks.all()}

        ids_to_delete = set(block_map.keys()) - payload_block_ids
        if ids_to_delete:
            project.blocks.filter(id__in=ids_to_delete).delete()

        for block_id in payload_block_ids:
            if block_id in block_map:
                block = block_map[block_id]
                block.order += 10000
                block.save()

        for i, block_data in enumerate(payload.blocks):
            final_order = i + 1
            
            block_values = {
                'question': block_data.question,
                'type': block_data.type,
                'subtext': block_data.subtext.strip() if block_data.subtext else None,
                'image_url': block_data.image_url.strip() if block_data.image_url else None,
                'link_url': block_data.link_url.strip() if block_data.link_url else None,
            }

            if block_data.id:
                block = block_map[block_data.id]
                for key, value in block_values.items():
                    setattr(block, key, value)
                block.order = final_order
                block.save()
            else:
                block_values['order'] = final_order
                block = project.blocks.create(**block_values)
            
            # Processing answers
            payload_answer_ids = {a.id for a in block_data.answers if a.id is not None}
            answer_map = {a.id: a for a in block.answers.all()}
            
            answer_ids_to_delete = set(answer_map.keys()) - payload_answer_ids
            if answer_ids_to_delete:
                block.answers.filter(id__in=answer_ids_to_delete).delete()

            for answer_data in block_data.answers:
                if answer_data.id:
                    answer = answer_map[answer_data.id]
                    answer.text = answer_data.text
                    answer.is_correct = answer_data.is_correct
                    answer.save()
                else:
                    block.answers.create(text=answer_data.text, is_correct=answer_data.is_correct)

    return project

#? Delete Project
@router.delete("/{project_id}/", response={204: None}, auth=JWTAuth())
def delete_project(request, project_id: int):
    """
    Logically deletes a project created by the user.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)
    project.date_deleted = timezone.now()
    project.save()
    return 204, None