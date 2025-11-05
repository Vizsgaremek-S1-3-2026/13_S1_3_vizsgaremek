# cQuizy/cQuizy/api.py (The Global API)

from ninja import NinjaAPI
from users.api import router as users_router #? Import the router from the 'users' app
from groups.api import router as groups_router #? Import the router from the 'groups' app

api = NinjaAPI(title="cQuizy | API Docs", version="1.0.0", description="Auto generated API docs by Django Ninja using OpenAPI", urls_namespace='mainapi')

# Add the router from the 'users' app
api.add_router("/users/", users_router) #? Register the router from the 'users' app under the "/users" prefix
api.add_router("/groups/", groups_router) #? Register the router from the 'groups' app under the "/groups" prefix

#TODO You can add more routers here later
#TODO from products.api import router as products_router
#TODO api.add_router("/products/", products_router)