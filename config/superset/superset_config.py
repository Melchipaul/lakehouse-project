import os

# Superset specific config
ROW_LIMIT = 5000

# Flask App Builder configuration
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'supersetSecretKey2025')

# The SQLAlchemy connection string to your database backend
# Uses environment variables - set DATABASE_URI or individual vars
SQLALCHEMY_DATABASE_URI = os.environ.get(
    'DATABASE_URI',
    f"postgresql+psycopg2://{os.environ.get('POSTGRES_USER', 'lakehouse')}:{os.environ.get('POSTGRES_PASSWORD', 'changeme')}@postgres:5432/superset"
)

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = []
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365

# Set this API key to enable Mapbox visualizations
MAPBOX_API_KEY = ''

# Cache config
CACHE_CONFIG = {
    'CACHE_TYPE': 'SimpleCache',
    'CACHE_DEFAULT_TIMEOUT': 60 * 60 * 24,
}

# Disable example data loading
SUPERSET_WEBSERVER_PROTOCOL = 'http'
SUPERSET_WEBSERVER_ADDRESS = '0.0.0.0'
SUPERSET_WEBSERVER_PORT = 8088

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
}
