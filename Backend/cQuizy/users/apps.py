from django.apps import AppConfig


class UsersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'users'

    def ready(self):
        import users.signals    #! Ignore pylance warning 
                                #? This is needed to import the signals.py file when the app is ready
