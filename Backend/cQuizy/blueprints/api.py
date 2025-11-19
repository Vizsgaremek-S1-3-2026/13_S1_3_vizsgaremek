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

# Ahelyett, hogy a NinjaAPI-t használnánk, Router-t használunk az app-specifikus végpontokhoz
router = Router(tags=['Projects'])

#? Létrehozás
@router.post("/", response=ProjectOutSchema, auth=JWTAuth())
def create_project(request, payload: ProjectCreateSchema):
    """
    Létrehoz egy új, üres Projektet.
    """
    user = request.auth
    project = Project.objects.create(**payload.dict(), creator=user)
    return project

#? Projektek listázása
@router.get("/", response=List[ProjectOutSchema], auth=JWTAuth())
def list_projects(request):
    """
    Lekéri a felhasználó által létrehozott összes nem törölt projekt listáját.
    """
    user = request.auth
    return Project.objects.filter(creator=user, date_deleted__isnull=True)

#? Projekt lekérése
@router.get("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def get_project_details(request, project_id: int):
    """
    Lekéri egyetlen, a felhasználó által létrehozott projekt teljes, beágyazott részleteit.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)
    return project

#? Frissítés
@router.put("/{project_id}/", response=ProjectOutSchema, auth=JWTAuth())
def update_full_project(request, project_id: int, payload: ProjectUpdateSchema):
    """
    Intelligensen frissít egy projektet, minden üzleti szabályt (limitek, kérdéstípusok, üres értékek)
    érvényesítve mentés előtt.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)

    # --- TELJES VALIDÁCIÓS BLOKK ---

    if not payload.name or not payload.name.strip():
        return 400, {"detail": "A projekt neve nem lehet üres."}
    if len(payload.blocks) > 100:
        return 400, {"detail": "Egy projektnek nem lehet több, mint 100 kérdése."}

    for i, block_data in enumerate(payload.blocks):
        question_num = i + 1

        if not block_data.question or not block_data.question.strip():
            return 400, {"detail": f"A(z) #{question_num}. kérdés nem lehet üres."}
        
        # ÚJ: Minimum 2 válasz szabály feleletválasztós kérdéseknél
        if block_data.type in ['SINGLE', 'MULTIPLE'] and len(block_data.answers) < 2:
            return 400, {"detail": f"A(z) #{question_num}. kérdésnél ('{block_data.question[:20]}...') legalább két válasznak kell lennie."}

        if len(block_data.answers) > 10:
            return 400, {"detail": f"A(z) #{question_num}. kérdésnél ('{block_data.question[:20]}...') nem lehet több, mint 10 válasz."}
        
        for j, answer_data in enumerate(block_data.answers):
            answer_num = j + 1
            if not answer_data.text or not answer_data.text.strip():
                return 400, {"detail": f"A(z) #{question_num}. kérdésnél a(z) #{answer_num}. válasz nem lehet üres."}

        if block_data.type == 'SINGLE':
            correct_answers_count = sum(1 for answer in block_data.answers if answer.is_correct)
            if correct_answers_count > 1:
                return 400, {"detail": f"A(z) #{question_num}. kérdésnél ('{block_data.question[:20]}...') csak egy helyes válasz lehet."}
        if block_data.type == 'TEXT':
            if any(not answer.is_correct for answer in block_data.answers):
                return 400, {"detail": f"A(z) #{question_num}. kérdés ('{block_data.question[:20]}...') egy szöveges kérdés, de van helytelennek jelölt válasza."}

    with transaction.atomic():
        project.name = payload.name
        project.desc = payload.desc.strip() if payload.desc else None # Üres stringet None-ra konvertál
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
            
            # ÚJ: Adatok előkészítése a null konverzióhoz
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
            
            # Válaszok feldolgozása
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

#? Törlés
@router.delete("/{project_id}/", response={204: None}, auth=JWTAuth())
def delete_project(request, project_id: int):
    """
    Logikailag töröl egy, a felhasználó által létrehozott projektet.
    """
    user = request.auth
    project = get_object_or_404(Project, id=project_id, creator=user)
    project.date_deleted = timezone.now()
    project.save()
    return 204, None