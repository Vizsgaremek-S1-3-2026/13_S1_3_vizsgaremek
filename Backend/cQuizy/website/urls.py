from django.urls import path
from . import views

urlpatterns = [
    # Pages
    path('', views.home, name='home'),
    path('login/', views.login, name='login'),
    path('register/', views.register, name='register'),
    path('profile/', views.profile, name='profile'),
    path('groups/', views.groups, name='groups'),

    # Tests
    path('users/', views.user_list_view, name='user-list'),
]