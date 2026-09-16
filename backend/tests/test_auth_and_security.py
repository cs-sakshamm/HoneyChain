import pytest
from fastapi.testclient import TestClient
from backend.main import app, hash_password, create_access_token, decode_token
from backend.database import SessionLocal, init_db
from backend.models import User, Hive

@pytest.fixture(scope='module')
def client():
    init_db()
    return TestClient(app)

@pytest.fixture(scope='module')
def db():
    init_db()
    session = SessionLocal()
    yield session
    session.close()

def test_password_hashing():
    pwd = 'SuperSecurePass123!'
    hashed = hash_password(pwd)
    assert hashed != pwd
    assert hashed.startswith('$') or hashed.startswith('$')

def test_auth_registration_and_login(client, db):
    email = 'sec_harvester@example.com'
    pwd = 'SecureHrv2026!'
    reg_res = client.post('/api/auth/register', json={'name': 'Security Harvester', 'email': email, 'phone': '+919999888811', 'password': pwd, 'role': 'HARVESTER'})
    assert reg_res.status_code in (200, 201, 409)
    login_res = client.post('/api/auth/login', json={'emailOrPhone': email, 'password': pwd, 'role': 'HARVESTER'})
    assert login_res.status_code == 200
    token = login_res.json()['token']
    payload = decode_token(token)
    assert payload['email'] == email
    assert payload['role'] == 'HARVESTER'

def test_profile_gates_and_forbidden(client, db):
    inc_email = 'incomplete_harvester@example.com'
    client.post('/api/auth/register', json={'name': 'Unknown', 'email': inc_email, 'password': 'Pass123!', 'role': 'HARVESTER'})
    u = db.query(User).filter(User.email == inc_email).first()
    u.phone = None
    u.is_verified = False
    db.commit()
    token = create_access_token({'sub': u.id, 'email': u.email, 'role': u.role})
    headers = {'Authorization': f'Bearer {token}'}
    hive_res = client.post('/api/hives', json={'name': 'Forbidden Hive', 'apiaryLocation': 'Secret', 'userId': u.id}, headers=headers)
    assert hive_res.status_code == 403
    assert hive_res.json()['detail']['code'] == 'PROFILE_INCOMPLETE'