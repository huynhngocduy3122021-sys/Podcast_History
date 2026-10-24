-- Development-only accounts. The profile is installed by DatabaseSeeder.
-- Passwords are BCrypt hashes; plaintext credentials are documented in docs/DEV_ACCOUNTS.md.

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '10000000-0000-4000-8000-000000000001'::uuid,
    r.role_id,
    'ph_admin',
    'admin.podcasthistory@gmail.com',
    '$2a$10$FLKaBD85y8J9uB9.QzIMfOiBrESsZjkyT0.myY2.c0xdVBnpxo7ou',
    'Podcast History Admin',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '20000000-0000-4000-8000-000000000001'::uuid,
    r.role_id,
    'ph_staff01',
    'staff01@podcasthistory.local',
    '$2a$10$jizMrTXyKaRTwYBj39bxpu5lWW6/qpUuTuHivqw.urBRvmrKo.n3K',
    'Podcast History Staff 01',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'STAFF'
ON CONFLICT DO NOTHING;

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '20000000-0000-4000-8000-000000000002'::uuid,
    r.role_id,
    'ph_staff02',
    'staff02@podcasthistory.local',
    '$2a$10$Fbdj74CqBAJXGM5HLmsxruOieuJuDGNNEUJ9R/0GvC6AOQEZE6tEO',
    'Podcast History Staff 02',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'STAFF'
ON CONFLICT DO NOTHING;

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '20000000-0000-4000-8000-000000000003'::uuid,
    r.role_id,
    'ph_staff03',
    'staff03@podcasthistory.local',
    '$2a$10$i6RGMK3bAwI69oNvK7w0i.T9AbCVVzVCLNbKwcsIfqvii3K1s01MC',
    'Podcast History Staff 03',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'STAFF'
ON CONFLICT DO NOTHING;

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '20000000-0000-4000-8000-000000000004'::uuid,
    r.role_id,
    'ph_staff04',
    'staff04@podcasthistory.local',
    '$2a$10$vMfnqvITAUHn7vp3iIi2p.xYlTEB9nMcuyDYhwMd2xa3iipdsWg5a',
    'Podcast History Staff 04',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'STAFF'
ON CONFLICT DO NOTHING;

INSERT INTO "User" (
    user_id, role_id, username, email, password_hash, display_name,
    is_active, is_verified, created_at, updated_at
)
SELECT
    '20000000-0000-4000-8000-000000000005'::uuid,
    r.role_id,
    'ph_staff05',
    'staff05@podcasthistory.local',
    '$2a$10$MXI7D9o1jPecoHpuRsHi.ecZorhM2pYds0z021Z60yDJ/NLE5hvmm',
    'Podcast History Staff 05',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "Role" r
WHERE r.role_code = 'STAFF'
ON CONFLICT DO NOTHING;
