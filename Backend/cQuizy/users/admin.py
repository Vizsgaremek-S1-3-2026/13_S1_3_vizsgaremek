# users/admin.py

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser

class CustomUserAdmin(UserAdmin):
    # Add our custom fields to the admin display
    list_display = ('username', 'email', 'nickname', 'is_staff', 'date_deleted')
    
    # This adds our custom fields to the "edit user" page in the admin
    fieldsets = UserAdmin.fieldsets + (
        ('Custom Profile', {'fields': ('nickname', 'pfp_url', 'date_deleted')}),
    )

admin.site.register(CustomUser, CustomUserAdmin)