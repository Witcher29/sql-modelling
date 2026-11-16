-- Коворкинг: каркас схемы

-- Нужен для exclusion constraint по room_id (bigint) + диапазон
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- Пользователи ----------
CREATE TABLE app_user (
                          user_id       BIGSERIAL PRIMARY KEY,
                          email         TEXT NOT NULL UNIQUE
                              CHECK (position('@' in email) > 1),
                          full_name     TEXT NOT NULL,
                          phone         TEXT,
                          role          TEXT NOT NULL DEFAULT 'client'
                              CHECK (role IN ('guest', 'client', 'admin', 'manager')),
                          password_hash TEXT NOT NULL,
                          created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Комнаты ----------
CREATE TABLE room (
                      room_id     BIGSERIAL PRIMARY KEY,
                      code        TEXT NOT NULL UNIQUE,
                      name        TEXT NOT NULL,
                      capacity    INT  NOT NULL CHECK (capacity > 0),
                      hourly_rate NUMERIC(10, 2) NOT NULL DEFAULT 0
                          CHECK (hourly_rate >= 0),
                      is_active   BOOLEAN NOT NULL DEFAULT TRUE,
                      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Брони ----------
CREATE TABLE booking (
                         booking_id BIGSERIAL PRIMARY KEY,
                         room_id    BIGINT NOT NULL REFERENCES room(room_id)     ON DELETE RESTRICT,
                         user_id    BIGINT NOT NULL REFERENCES app_user(user_id) ON DELETE RESTRICT,
                         start_time TIMESTAMPTZ NOT NULL,
                         end_time   TIMESTAMPTZ NOT NULL,
                         status     TEXT NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'confirmed', 'cancelled', 'expired')),
                         created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- 5.2: конец строго позже начала
                         CONSTRAINT booking_time_order CHECK (end_time > start_time),
    -- 5.6: нельзя бронировать в прошлом (старт позже момента создания)
                         CONSTRAINT booking_not_in_past CHECK (start_time > created_at),
    -- 5.7: максимум 12 часов
                         CONSTRAINT booking_max_duration
                             CHECK (end_time - start_time <= interval '12 hours')
    );

-- 5.1: в одной комнате нет двух активных броней с пересечением по времени.
-- Диапазон [start, end) — брони «встык» не считаются пересечением.
ALTER TABLE booking
    ADD CONSTRAINT booking_no_overlap
    EXCLUDE USING gist (
    room_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  )
  WHERE (status IN ('pending', 'confirmed'));

CREATE INDEX ix_booking_room_time ON booking (room_id, start_time, end_time);
CREATE INDEX ix_booking_user      ON booking (user_id);

-- ---------- Платежи ----------
CREATE TABLE payment (
                         payment_id BIGSERIAL PRIMARY KEY,
                         booking_id BIGINT NOT NULL UNIQUE
                             REFERENCES booking(booking_id) ON DELETE CASCADE,
                         amount     NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
                         status     TEXT NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'paid', 'refunded', 'failed')),
                         paid_at    TIMESTAMPTZ,
                         created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Журнал событий по броням ----------
CREATE TABLE booking_event (
                               event_id   BIGSERIAL PRIMARY KEY,
                               booking_id BIGINT NOT NULL
                                   REFERENCES booking(booking_id) ON DELETE CASCADE,
                               event_type TEXT NOT NULL
                                   CHECK (event_type IN
                                          ('created', 'paid', 'confirmed', 'cancelled', 'refund_issued')),
                               actor_id   BIGINT REFERENCES app_user(user_id),
                               payload    JSONB NOT NULL DEFAULT '{}'::jsonb,
                               created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_booking_event_booking_time
    ON booking_event (booking_id, created_at);
CREATE INDEX ix_booking_event_payload_gin
    ON booking_event USING gin (payload);