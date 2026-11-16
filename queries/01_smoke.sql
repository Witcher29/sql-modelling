-- Smoke-тест для системы бронирования коворкинга

-- 1. Версия
SELECT version();

-- 2. Вставка корректных данных
-- Очищаем таблицы перед тестом (на случай повторного запуска)
TRUNCATE booking_event, payment, booking, room, app_user RESTART IDENTITY CASCADE;

-- Добавляем комнаты
INSERT INTO room (code, name, capacity, hourly_rate)
VALUES
    ('A101', 'Переговорная "Альфа"', 4, 500.00),
    ('A102', 'Переговорная "Бета"', 6, 800.00);

-- Добавляем пользователей (пароль-хэш для теста)
INSERT INTO app_user (email, full_name, phone, role, password_hash)
VALUES
    ('alice@example.com', 'Алиса Смит', '+79990001122', 'client', 'dummy_hash_1'),
    ('bob@example.com', 'Боб Джонс', '+79990003344', 'admin', 'dummy_hash_2');

-- Добавляем бронь
INSERT INTO booking (room_id, user_id, start_time, end_time, status)
VALUES
    (1, 1, now() + interval '1 day', now() + interval '1 day 2 hours', 'confirmed');

-- Добавляем платеж
INSERT INTO payment (booking_id, amount, status, paid_at)
VALUES
    (1, 1000.00, 'paid', now());

-- 3. Чтение
SELECT * FROM room;
SELECT * FROM app_user;
SELECT * FROM booking;
SELECT * FROM payment;

-- 4. Негативный тест FK: ожидается ошибка
-- Внимание: раскомментируйте строку ниже и выполните ее ОТДЕЛЬНО.
-- INSERT INTO booking (room_id, user_id, start_time, end_time)
-- VALUES (999999, 999999, now() + interval '2 days', now() + interval '2 days 1 hour');