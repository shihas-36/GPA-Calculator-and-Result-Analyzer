# Django + Flutter App - Render Deployment Checklist

## Critical Issues Found (MUST FIX BEFORE DEPLOYING)

### 1. **SECURITY: Exposed Credentials in Code** ⚠️ CRITICAL
**Location:** `gpabackend/gpabackend/settings.py` (lines 12, 162, 162)

**Issues:**
- `SECRET_KEY` has a fallback to a hardcoded insecure key
- `JWT_SIGNING_KEY` defaults to placeholder `'your_secret_key'`
- `EMAIL_HOST_PASSWORD` is hardcoded: `'asljntvdbcryzayk'`
- `EMAIL_HOST_USER` is hardcoded: `'gcalculator94@gmail.com'`

**Fix Required:**
```python
# Update settings.py
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')
if not SECRET_KEY:
    raise ValueError("DJANGO_SECRET_KEY environment variable must be set")

# For email
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD')

# For JWT
SIMPLE_JWT = {
    'SIGNING_KEY': os.environ.get('JWT_SIGNING_KEY', SECRET_KEY),
    ...
}
```

**Action:** Set these environment variables in Render dashboard:
- `DJANGO_SECRET_KEY` → Generate a new secure key
- `EMAIL_HOST_USER` → Your Gmail address
- `EMAIL_HOST_PASSWORD` → Your Gmail app password
- `JWT_SIGNING_KEY` → Same as DJANGO_SECRET_KEY or different strong key

---

### 2. **DEBUG Mode is ON** ⚠️ CRITICAL
**Location:** `gpabackend/gpabackend/settings.py` (line 14)

**Issue:**
```python
DEBUG = True  # This reveals sensitive info in production
```

**Fix:**
```python
DEBUG = os.environ.get('DEBUG', 'False') == 'True'
```

**Action:** In Render, set `DEBUG = False` (default) or don't set the env var.

---

### 3. **SQLite Database** ⚠️ CRITICAL
**Location:** `gpabackend/gpabackend/settings.py` (lines 84-87)

**Issue:**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
```
SQLite is file-based and won't persist on Render (ephemeral filesystem). Data will be lost on restart/redeploy.

**Fix - Use PostgreSQL:**
```python
import dj_database_url

DATABASES = {
    'default': dj_database_url.config(
        default='sqlite:///db.sqlite3',
        conn_max_age=600
    )
}
```

**Action:**
1. Add to `requirment.txt`:
   ```
   dj-database-url==1.3.0
   psycopg2-binary==2.9.9
   ```
2. Provision PostgreSQL on Render (paid tier starts at $15/month, or use managed Postgres)
3. Set `DATABASE_URL` environment variable in Render to your PostgreSQL connection string

---

### 4. **ALLOWED_HOSTS is Hardcoded for Development** ⚠️ HIGH
**Location:** `gpabackend/gpabackend/settings.py` (lines 17-21)

**Issue:**
```python
ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    '10.0.2.2'  # Android emulator
]
```

**Fix:**
```python
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
```

**Action:** In Render, set:
```
ALLOWED_HOSTS = your-render-url.onrender.com,your-custom-domain.com
```

---

### 5. **CORS Configuration is Too Permissive** ⚠️ HIGH
**Location:** `gpabackend/gpabackend/settings.py` (lines 56-62)

**Issue:**
```python
CORS_ORIGIN_ALLOW_ALL = True  # Allows ANY origin
CORS_ALLOWED_ORIGINS = ["http://localhost:8000", ...]
```

**Fix for Production:**
```python
CORS_ORIGIN_ALLOW_ALL = os.environ.get('CORS_ORIGIN_ALLOW_ALL', 'False') == 'True'

CORS_ALLOWED_ORIGINS = os.environ.get(
    'CORS_ALLOWED_ORIGINS',
    'http://localhost:3000,http://127.0.0.1:8000'
).split(',')

# For your Flutter app (update with actual domain after deployment)
# Example:
# CORS_ALLOWED_ORIGINS = [
#     'https://yourdomain.com',
#     'https://api.yourdomain.com',
# ]
```

**Action:** Set in Render:
```
CORS_ALLOWED_ORIGINS = https://your-flutter-app-domain.com
```

---

### 6. **Static Files Not Configured for Production** ⚠️ MEDIUM
**Location:** `gpabackend/gpabackend/settings.py` (lines 124-125)

**Issue:**
```python
STATIC_URL = 'static/'
# Missing STATIC_ROOT and STATIC_FILES_STORAGE
```

**Fix:**
```python
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

**Action:**
1. Add to `requirment.txt`:
   ```
   whitenoise==6.6.0
   ```
2. Update `middleware` in settings.py to include WhiteNoise (after SecurityMiddleware):
   ```python
   MIDDLEWARE = [
       'django.middleware.security.SecurityMiddleware',
       'whitenoise.middleware.WhiteNoiseMiddleware',  # Add this
       'django.contrib.sessions.middleware.SessionMiddleware',
       ...
   ]
   ```

---

### 7. **Missing `requirements.txt` (Typo: `requirment.txt`)** ⚠️ HIGH
**Location:** Root and app folders have `requirment.txt` (misspelled)

**Issue:**
Render looks for `requirements.txt` (with 'e'). The typo will cause build to fail.

**Fix:**
1. Rename `requirment.txt` → `requirements.txt`
2. Complete contents:
   ```
   Django==5.1
   djangorestframework==3.14.0
   djangorestframework-simplejwt==5.2.2
   django-cors-headers==3.14.0
   python-decouple==3.8
   dj-database-url==1.3.0
   psycopg2-binary==2.9.9
   whitenoise==6.6.0
   gunicorn==21.2.0
   ```

---

### 8. **No Web Server Configuration** ⚠️ CRITICAL
**Issue:**
Render needs a web server (WSGI app).

**Fix:**
1. Add `Procfile` in project root:
   ```
   web: gunicorn gpabackend.wsgi:application
   ```

2. Ensure `gunicorn` is in `requirements.txt`

---

### 9. **No `.env` File or Environment Management** ⚠️ MEDIUM
**Issue:**
Secrets hardcoded in code instead of environment variables.

**Action:**
1. Create `.env.example` for reference (never commit `.env` with real secrets):
   ```
   DEBUG=False
   DJANGO_SECRET_KEY=your-secret-key-here
   DATABASE_URL=postgresql://user:pass@host/db
   EMAIL_HOST_USER=your-gmail@gmail.com
   EMAIL_HOST_PASSWORD=your-app-password
   JWT_SIGNING_KEY=your-jwt-key
   ALLOWED_HOSTS=api.yourdomain.com
   CORS_ALLOWED_ORIGINS=https://yourdomain.com
   ```

2. Never commit real `.env` to git (add to `.gitignore`)

---

### 10. **Flutter App Hardcoded Backend URL** ⚠️ MEDIUM
**Location:** `gpa_frontend/lib/services/api_service.dart`

**Issue:**
Frontend has hardcoded `10.0.2.2:8000` (Android emulator).

**Fix:**
- Update `ApiService` to use environment-aware base URL
- For production: set it to your Render app URL

**Example:**
```dart
static String baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',  // Dev default
);
```

**Action:** When releasing to production, rebuild Flutter with:
```bash
flutter run --dart-define=API_BASE_URL=https://your-render-api-url.onrender.com
```

---

## Pre-Deployment Checklist

- [ ] Fix SECRET_KEY and all hardcoded credentials
- [ ] Set DEBUG = False for production
- [ ] Migrate from SQLite to PostgreSQL
- [ ] Update ALLOWED_HOSTS
- [ ] Restrict CORS to specific origins only
- [ ] Configure static files with WhiteNoise
- [ ] Rename `requirment.txt` → `requirements.txt`
- [ ] Create `Procfile` for Gunicorn
- [ ] Test locally with production settings:
  ```bash
  DEBUG=False python manage.py collectstatic --noinput
  python manage.py runserver
  ```
- [ ] Create Render environment variables (see above)
- [ ] Test database migrations on Render
- [ ] Update Flutter app backend URL to point to Render
- [ ] Test complete flow (signup, login, grade entry, persistence)
- [ ] Set up HTTPS/SSL (Render provides free SSL)
- [ ] Monitor logs after first deploy

---

## Render Deployment Steps (After Fixes)

1. **Push code to GitHub** (with secrets removed)
2. **Create Render Account** and link GitHub repo
3. **Create Web Service** on Render:
   - Runtime: Python 3.9+
   - Build command: `pip install -r requirements.txt && python manage.py migrate`
   - Start command: `gunicorn gpabackend.wsgi:application`
4. **Set Environment Variables** in Render dashboard
5. **Provision PostgreSQL** database and add `DATABASE_URL`
6. **Deploy** and monitor logs

---

## Additional Recommendations

### Database Backups
- Enable automatic backups on Render PostgreSQL (paid feature)
- Alternatively, use `pg_dump` for periodic backups

### Email in Production
- Gmail's app passwords have a 30-character limit and may have limitations
- Consider using a dedicated email service (SendGrid, Mailgun) for reliability
- Current setup works but less reliable for production

### Monitoring & Logging
- Add error tracking (Sentry.io)
- Monitor API response times and failures
- Set up alerts for production issues

### API Rate Limiting
- Consider adding rate limiting to prevent abuse
- Use `django-ratelimit` or DRF throttling

### Data Security
- Ensure all API calls use HTTPS (Render provides free SSL)
- Hash sensitive user data where possible
- Regular security audits and dependency updates

