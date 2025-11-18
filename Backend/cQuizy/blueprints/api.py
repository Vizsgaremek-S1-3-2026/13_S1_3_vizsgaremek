# cQuizy/blueprints/api.py

from ninja import Router

#? Instead of NinjaAPI, we use Router
router = Router(tags=['Projects'])  # The 'tags' are great for organizing docs