from django.urls import path
from . import views

urlpatterns = [
    # Pages
    path('', views.home, name='home'),
    path('login/', views.login, name='login'),
    path('register/', views.register, name='register'),

    # Tests
    path('users/', views.user_list_view, name='user-list'),
]