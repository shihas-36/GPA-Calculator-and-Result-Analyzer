from django.contrib import admin
from django.urls import path, include
from accounts.views import LoginView  # Use your custom LoginView instead of simplejwt

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('calculator.urls')),  # Include the calculator app URLs
    path('', include('accounts.urls')),
    path('token/', LoginView.as_view(), name='token_obtain_pair'),  # Use custom LoginView
]
