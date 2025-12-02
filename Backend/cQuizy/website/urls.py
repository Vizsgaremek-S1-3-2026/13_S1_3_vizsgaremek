#cQuizy/website/urls.py

from django.urls import path
from . import views
from .views import BuilderView, GroupPageView, QuizPageView, QuizAdminView

urlpatterns = [
    # Pages
    path('', views.home, name='home'),
    path('login/', views.login, name='login'),
    path('register/', views.register, name='register'),
    path('profile/', views.profile, name='profile'),
    path('groups/', views.groups, name='groups'),
    path('grouppage/', GroupPageView.as_view(), name='grouppage'),
    path('quiz/', QuizPageView.as_view(), name='quiz'),
    path('quizadmin/', QuizAdminView.as_view(), name='quizadmin'),
    path('projects/', views.projects, name='projects'),
    path('builder/', BuilderView.as_view(), name='builder'),
]