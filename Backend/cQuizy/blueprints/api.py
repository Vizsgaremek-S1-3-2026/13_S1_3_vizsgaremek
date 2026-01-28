# cQuizy/blueprints/api.py
# AKA Projects APIs

from ninja import Router
from ninja.errors import HttpError 
from typing import List, Optional, Union
from django.db import transaction
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db.models import Q

from .models import Project, Block, Answer
from .schemas import (
    ProjectCreateSchema,
    ProjectUpdateSchema,
    ProjectOutSchema,
    BlockOutSchema
)

from users.auth import JWTAuth

router = Router(tags=['Projects'])

#! Error Handling
from ninja import Schema
class ErrorSchema(Schema):
    detail: str

#! API Endpoints
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
    Searches for blocks.
    UPDATED: Now searches in 'maintext' instead of 'question'.
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
            # Changed 'question' to 'maintext' and added 'gap_text'
            blocks_qs = blocks_qs.filter(
                Q(maintext__icontains=query) | 
                Q(gap_text__icontains=query) |
                Q(subtext__icontains=query)
            )
        elif mode == 'answer':
            blocks_qs = blocks_qs.filter(
                answers__text__icontains=query
            )
        else: # 'both'
            blocks_qs = blocks_qs.filter(
                Q(maintext__icontains=query) | 
                Q(gap_text__icontains=query) |
                Q(subtext__icontains=query) |
                Q(answers__text__icontains=query)
            )
    
    # 3. Limit results to 20.
    blocks_qs = blocks_qs.distinct()[:20]

    return blocks_qs

#? Retrieve Project
@router.get("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def get_project_details(request, project_id: int):
    """
    Retrieves full, nested details of a single project.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user, date_deleted__isnull=True)
    return project

#? Update Project
@router.put("/{project_id}/", response={200: ProjectOutSchema, 400: ErrorSchema}, auth=JWTAuth())
def update_full_project(request, project_id: int, payload: ProjectUpdateSchema):
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user, date_deleted__isnull=True)

    # --- MAPPING & WHITELIST DEFINITION ---
    
    # 1. Frontend Short Codes -> Backend DB Values
    TYPE_MAPPING = {
        'single': Block.BlockType.SINGLE_CHOICE,
        'multiple': Block.BlockType.MULTIPLE_CHOICE,
        'text': Block.BlockType.TEXT_INPUT,
        'text_block': Block.BlockType.TEXT_STATIC,
        'divider': Block.BlockType.DIVIDER,
        'matching': Block.BlockType.MATCHING,
        'ordering': Block.BlockType.ORDERING,
        'sentence_ordering': Block.BlockType.SENTENCE_ORDERING,
        'gap_fill': Block.BlockType.GAP_FILL,
        'range': Block.BlockType.RANGE,
    }

    # 2. Get list of all allowed Backend Types (e.g., 'single_choice', 'text_input'...)
    # This prevents anyone from sending "garbage" or "unknown" types.
    ALLOWED_DB_TYPES = set(Block.BlockType.values)

    # 3. Define groups for validation logic
    STATIC_TYPES = ['text_static', 'divider']
    MULTI_OPTION_TYPES = ['single_choice', 'multiple_choice', 'ordering', 'matching', 'sentence_ordering']

    # --- FULL VALIDATION BLOCK ---

    if not payload.name or not payload.name.strip():
        return 400, {"detail": "Project name cannot be empty."}
    if len(payload.blocks) > 100:
        return 400, {"detail": "A project cannot have more than 100 questions."}

    for i, block_data in enumerate(payload.blocks):
        q_num = i + 1
        
        # 1. NORMALIZE TYPE
        # Attempt to map Frontend -> Backend. If not found, keep original.
        clean_type = TYPE_MAPPING.get(block_data.type, block_data.type)

        # SECURITY CHECK: strict whitelist
        if clean_type not in ALLOWED_DB_TYPES:
            return 400, {"detail": f"Question #{q_num}: Invalid or unknown block type '{block_data.type}'."}

        # 2. Validate Main Content
        if clean_type == 'gap_fill':
            if not block_data.gap_text or not block_data.gap_text.strip():
                return 400, {"detail": f"Question #{q_num}: Gap text cannot be empty."}
        elif clean_type not in STATIC_TYPES: 
            if not block_data.maintext or not block_data.maintext.strip():
                return 400, {"detail": f"Question #{q_num}: Main text/Question cannot be empty."}
        
        # 3. Validate Answer Counts
        if clean_type not in STATIC_TYPES:
            if clean_type in MULTI_OPTION_TYPES:
                if len(block_data.answers) < 2:
                    return 400, {"detail": f"Question #{q_num} must have at least two options."}
            
            if len(block_data.answers) > 20: 
                return 400, {"detail": f"Question #{q_num} cannot have more than 20 answers."}
        
        # 4. Validate Individual Answers
        for j, answer_data in enumerate(block_data.answers):
            a_num = j + 1
            
            if clean_type == 'matching':
                if not answer_data.text or not answer_data.text.strip():
                    return 400, {"detail": f"Question #{q_num}, Answer #{a_num}: Left side text is missing."}
                if not answer_data.match_text or not answer_data.match_text.strip():
                    return 400, {"detail": f"Question #{q_num}, Answer #{a_num}: Right side (match) text is missing."}
            
            elif clean_type == 'range':
                if answer_data.numeric_value is None:
                    return 400, {"detail": f"Question #{q_num}: Numeric value is missing."}

            elif clean_type == 'gap_fill':
                if not answer_data.text:
                     return 400, {"detail": f"Question #{q_num}, Answer #{a_num}: Answer text is missing."}
                if answer_data.gap_index is None:
                     return 400, {"detail": f"Question #{q_num}, Answer #{a_num}: Gap index is missing."}

            elif clean_type in MULTI_OPTION_TYPES or clean_type == 'text_input':
                if not answer_data.text or not answer_data.text.strip():
                    return 400, {"detail": f"Question #{q_num}, Answer #{a_num} cannot be empty."}

        # 5. Validate Correct Answers Logic
        if clean_type == 'single_choice':
            correct_answers_count = sum(1 for answer in block_data.answers if answer.is_correct)
            if correct_answers_count == 0:
                return 400, {"detail": f"Question #{q_num} (Single Choice) has no correct answer selected."}
            if correct_answers_count > 1:
                return 400, {"detail": f"Question #{q_num} (Single Choice) can only have one correct answer."}
        
        if clean_type == 'text_input':
             if any(not answer.is_correct for answer in block_data.answers):
                return 400, {"detail": f"Question #{q_num} is a text input but has an answer marked as incorrect."}

    # --- SAVING LOGIC ---
    
    with transaction.atomic():
        project.name = payload.name
        project.desc = payload.desc.strip() if payload.desc else None
        project.save()

        # Handle Blocks Deletion
        payload_block_ids = {b.id for b in payload.blocks if b.id is not None}
        block_map = {b.id: b for b in project.blocks.all()}

        ids_to_delete = set(block_map.keys()) - payload_block_ids
        if ids_to_delete:
            project.blocks.filter(id__in=ids_to_delete).delete()

        # Shift orders
        for block_id in payload_block_ids:
            if block_id in block_map:
                block = block_map[block_id]
                block.order += 10000
                block.save()

        # Iterate Blocks
        for i, block_data in enumerate(payload.blocks):
            final_block_order = i + 1
            
            # Recalculate type (safe because we validated it above)
            db_type = TYPE_MAPPING.get(block_data.type, block_data.type)

            block_values = {
                'type': db_type,
                'maintext': block_data.maintext,
                'gap_text': block_data.gap_text,
                'subtext': block_data.subtext.strip() if block_data.subtext else None,
                'image_url': block_data.image_url.strip() if block_data.image_url else None,
                'link_url': block_data.link_url.strip() if block_data.link_url else None,
            }

            if block_data.id:
                block = block_map[block_data.id]
                for key, value in block_values.items():
                    setattr(block, key, value)
                block.order = final_block_order
                block.save()
            else:
                block_values['order'] = final_block_order
                block = project.blocks.create(**block_values)
            
            # Handle Answers
            payload_answer_ids = {a.id for a in block_data.answers if a.id is not None}
            answer_map = {a.id: a for a in block.answers.all()}
            
            answer_ids_to_delete = set(answer_map.keys()) - payload_answer_ids
            if answer_ids_to_delete:
                block.answers.filter(id__in=answer_ids_to_delete).delete()

            for j, answer_data in enumerate(block_data.answers):
                final_answer_order = j + 1

                answer_values = {
                    'text': answer_data.text,
                    'is_correct': answer_data.is_correct,
                    'points': answer_data.points,
                    'order': final_answer_order,
                    'match_text': answer_data.match_text,
                    'gap_index': answer_data.gap_index,
                    'numeric_value': answer_data.numeric_value,
                    'tolerance': answer_data.tolerance,
                }

                if answer_data.id:
                    answer = answer_map[answer_data.id]
                    for key, value in answer_values.items():
                        setattr(answer, key, value)
                    answer.save()
                else:
                    block.answers.create(**answer_values)

    return 200, project

#? Delete Project
@router.delete("/{project_id}/", response={204: None}, auth=JWTAuth())
def delete_project(request, project_id: int):
    """
    Logically deletes a project created by the user.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user, date_deleted__isnull=True)
    project.date_deleted = timezone.now()
    project.save()
    return 204, None