from django.urls import path
from . import views

urlpatterns = [
    # Pages
    path('', views.home, name='home'),
    path('login/', views.login, name='login'),

    # Tests
    path('users/', views.user_list_view, name='user-list'),
]