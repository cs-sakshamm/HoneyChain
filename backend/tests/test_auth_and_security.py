import pytest
import uuid
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

def test_profile_completion_then_add_hive_end_to_end(client, db):
    suffix = uuid.uuid4().hex[:8]
    email = f'e2e_harvester_{suffix}@example.com'
    pwd = 'SecureHrv2026!'

    reg_res = client.post('/api/auth/register', json={
        'name': 'Unknown',
        'email': email,
        'password': pwd,
        'role': 'HARVESTER',
    })
    assert reg_res.status_code in (200, 201)

    login_res = client.post('/api/auth/login', json={
        'emailOrPhone': email,
        'password': pwd,
        'role': 'HARVESTER',
    })
    assert login_res.status_code == 200
    token = login_res.json()['token']
    user_id = login_res.json()['user']['id']
    headers = {'Authorization': f'Bearer {token}'}

    blocked_res = client.post('/api/hives', json={
        'name': 'Blocked Hive',
        'hiveCode': f'HC-BLOCK-{suffix}',
        'apiaryLocation': 'North Apiary',
    }, headers=headers)
    assert blocked_res.status_code == 403
    assert blocked_res.json()['detail']['code'] == 'PROFILE_INCOMPLETE'

    profile_res = client.put('/api/profile', json={
        'userId': user_id,
        'name': 'End To End Harvester',
        'phone': '+15550199',
    }, headers=headers)
    assert profile_res.status_code == 200
    assert profile_res.json()['isProfileComplete'] is True

    refresh_res = client.get('/api/profile', headers=headers)
    assert refresh_res.status_code == 200
    assert refresh_res.json()['profile']['id'] == user_id
    assert refresh_res.json()['isProfileComplete'] is True

    hive_res = client.post('/api/hives', json={
        'name': 'E2E Hive',
        'hiveCode': f'HC-E2E-{suffix}',
        'apiaryLocation': 'North Apiary',
        'hiveType': 'Langstroth',
        'dateAdded': '2026-09-19T10:00:00',
        'queenStatus': 'Mated',
        'totalFrames': 12,
        'broodFrames': 7,
        'colonyStrength': 'Strong',
        'queenAgeMonths': 14,
        'beeBreed': 'Italian',
        'expectedProductionKg': 12.5,
        'previousYearProductionKg': 8.25,
        'currentYearProductionKg': 3.75,
        'honeyType': 'Wildflower',
        'lastInspectionDate': '2026-09-18T09:30:00',
        'miteStatus': 'Low',
        'diseaseStatus': 'None',
        'feedingRequired': False,
        'queenCondition': 'Good',
        'overallHealth': 'Healthy',
        'notes': 'Created from Flutter Add Hive form payload.',
    }, headers=headers)
    assert hive_res.status_code == 200
    body = hive_res.json()
    assert body['success'] is True
    assert body['hive']['userId'] == user_id
    assert body['hive']['previousYearProductionKg'] == 8.25
    assert body['hive']['currentYearProductionKg'] == 3.75
    assert body['hive']['broodFrames'] == 7

    hive = db.query(Hive).filter(Hive.id == body['hive']['id']).first()
    assert hive is not None
    assert hive.user_id == user_id
    assert hive.previous_year_production_kg == 8.25
    assert hive.current_year_production_kg == 3.75
    assert hive.last_inspection_date.isoformat().startswith('2026-09-18T09:30:00')

def test_harvester_role_alias_can_add_hive(client, db):
    suffix = uuid.uuid4().hex[:8]
    password = 'SecureHrv2026!'
    user = User(
        name='Alias Harvester',
        email=f'alias_harvester_{suffix}@example.com',
        password_hash=hash_password(password),
        role='BEEKEEPER',
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    login_res = client.post('/api/auth/login', json={
        'emailOrPhone': user.email,
        'password': password,
        'role': 'HARVESTER',
    })
    assert login_res.status_code == 200
    token = login_res.json()['token']
    res = client.post('/api/hives', json={
        'name': 'Alias Hive',
        'hiveCode': f'HC-ALIAS-{suffix}',
        'apiaryLocation': 'Alias Apiary',
    }, headers={'Authorization': f'Bearer {token}'})

    assert res.status_code == 200
    body = res.json()
    assert body['success'] is True
    assert body['hive']['userId'] == user.id
