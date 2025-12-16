# cQuizy/cQuizy/api.py (The Global API)

from ninja import NinjaAPI
from users.api import router as users_router #? Import the router from the 'users' app
from groups.api import router as groups_router #? Import the router from the 'groups' app
from blueprints.api import router as blueprints_router #? Import the router from the 'blueprints' app
from quizzes.api import router as quizzes_router #? Import the router from the 'quizzes' app

api = NinjaAPI(title="cQuizy | API Docs", version="1.0.0", description="Auto generated API docs by Django Ninja using OpenAPI", urls_namespace='mainapi')

# Add the router from the 'users' app
api.add_router("/users/", users_router) #? Register the router from the 'users' app under the "/users" prefix
api.add_router("/groups/", groups_router) #? Register the router from the 'groups' app under the "/groups" prefix
api.add_router("/blueprints/", blueprints_router) #? Register the router from the 'blueprints' app under the "/blueprints" prefix
api.add_router("/quizzes/", quizzes_router) #? Register the router from the 'quizzes' app under the "/quizzes" prefix

#TODO You can add more routers here later
#TODO from products.api import router as products_router
#TODO api.add_router("/products/", products_router)