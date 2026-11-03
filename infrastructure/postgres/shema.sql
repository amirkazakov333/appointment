-- =========================================================
-- USERS
-- Зона ответственности: Identity Service
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,

    phone VARCHAR(20) NOT NULL UNIQUE,

    password_hash TEXT NOT NULL,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,

    role VARCHAR(20) NOT NULL DEFAULT 'patient',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT users_role_check
        CHECK (
            role IN (
                'patient',
                'doctor',
                'operator'
            )
        )
);


-- =========================================================
-- REFRESH TOKENS
-- Зона ответственности: Identity Service
-- =========================================================

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    token_hash TEXT NOT NULL UNIQUE,

    expires_at TIMESTAMPTZ NOT NULL,

    revoked_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id
    ON refresh_tokens(user_id);


CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
    ON refresh_tokens(expires_at);


-- =========================================================
-- APPOINTMENTS
-- Зона ответственности: Appointment Service
-- =========================================================

CREATE TABLE IF NOT EXISTS appointments (
    id BIGSERIAL PRIMARY KEY,

    patient_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE RESTRICT,

    -- ID врача из внешней системы расписания
    doctor_id BIGINT NOT NULL,

    -- ID слота из внешней системы расписания
    slot_id BIGINT NOT NULL,

    appointment_start TIMESTAMPTZ NOT NULL,

    -- Кабинет на момент создания записи
    room VARCHAR(100),

    status VARCHAR(20) NOT NULL DEFAULT 'confirmed',

    cancelled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT appointments_status_check
        CHECK (
            status IN (
                'confirmed',
                'cancelled',
                'completed',
                'no_show'
            )
        )
);


-- Один слот не может одновременно иметь
-- две активные записи.
--
-- После cancelled слот может использоваться повторно.
CREATE UNIQUE INDEX IF NOT EXISTS uq_appointments_active_slot
    ON appointments(slot_id)
    WHERE status <> 'cancelled';


CREATE INDEX IF NOT EXISTS idx_appointments_patient_id
    ON appointments(patient_id);


CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id
    ON appointments(doctor_id);


CREATE INDEX IF NOT EXISTS idx_appointments_start
    ON appointments(appointment_start);


CREATE INDEX IF NOT EXISTS idx_appointments_status
    ON appointments(status);


-- =========================================================
-- APPOINTMENT STATUS HISTORY
-- История изменения статусов записи
-- =========================================================

CREATE TABLE IF NOT EXISTS appointment_status_history (
    id BIGSERIAL PRIMARY KEY,

    appointment_id BIGINT NOT NULL
        REFERENCES appointments(id)
        ON DELETE CASCADE,

    old_status VARCHAR(20),

    new_status VARCHAR(20) NOT NULL,

    -- Пользователь, который изменил статус
    changed_by_user_id BIGINT
        REFERENCES users(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT appointment_history_old_status_check
        CHECK (
            old_status IS NULL
            OR old_status IN (
                'confirmed',
                'cancelled',
                'completed',
                'no_show'
            )
        ),

    CONSTRAINT appointment_history_new_status_check
        CHECK (
            new_status IN (
                'confirmed',
                'cancelled',
                'completed',
                'no_show'
            )
        )
);


CREATE INDEX IF NOT EXISTS idx_appointment_history_appointment_id
    ON appointment_status_history(appointment_id);


CREATE INDEX IF NOT EXISTS idx_appointment_history_changed_by_user_id
    ON appointment_status_history(changed_by_user_id);