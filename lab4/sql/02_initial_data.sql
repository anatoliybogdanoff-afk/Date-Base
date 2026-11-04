SET search_path TO transport_card;

BEGIN;

INSERT INTO e1_card_owner (passport_data, full_name, phone_number, email) VALUES
('4500 100001', 'Анна Сергеева', '+79990000001', 'anna@example.ru'),
('4500 100002', 'Иван Петров', '+79990000002', 'ivan@example.ru'),
('4500 100003', 'Мария Орлова', '+79990000003', 'maria@example.ru'),
('4500 100004', 'Олег Соколов', '+79990000004', 'oleg@example.ru'),
('4500 100005', 'Елена Волкова', '+79990000005', 'elena@example.ru');

INSERT INTO e16_employee_operator (passport_data, full_name, work_email) VALUES
('4500 900001', 'Павел Смирнов', 'p.smirnov@transport.ru'),
('4500 900002', 'Дарья Белова', 'd.belova@transport.ru'),
('4500 900003', 'Максим Крылов', 'm.krylov@transport.ru');

INSERT INTO e2_card (card_number, owner_id, issue_date, validity_period_days, current_balance, status) VALUES
('T0000000001', 1, DATE '2026-01-10', 1825, 850.00, 'reissued'),
('T0000000002', 2, DATE '2026-02-01', 1825, 430.00, 'active'),
('T0000000003', 3, DATE '2026-03-15', 1825, 1200.00, 'active'),
('T0000000004', 4, DATE '2025-11-20', 1825, 90.00, 'blocked'),
('T0000000005', NULL, DATE '2026-05-01', 1825, 0.00, 'active'),
('T0000000006', 1, DATE '2026-10-01', 1825, 850.00, 'active');

INSERT INTO e4_benefit (owner_id, benefit_type, assignment_basis, start_date, end_date) VALUES
(1, 'student', 'Студенческий билет', DATE '2026-09-01', DATE '2027-08-31'),
(3, 'pensioner', 'Пенсионное удостоверение', DATE '2025-01-01', NULL);

INSERT INTO e5_tariff_product (product_name, trip_count, price, status) VALUES
('Единичная поездка', 1, 70.00, 'active'),
('20 поездок', 20, 1200.00, 'active'),
('Безлимитный 30 дней', NULL, 3150.00, 'active');

INSERT INTO e7_transport_object (object_code, object_type, object_name, status) VALUES
('METRO-001', 'metro_station', 'Октябрьская', 'active'),
('METRO-002', 'metro_station', 'Технопарк', 'active'),
('BUS-101', 'bus', 'Автобус 101', 'active'),
('TRAM-017', 'tram', 'Трамвай 17', 'maintenance');

INSERT INTO e8_validator (validator_code, transport_object_id, installed_at, status) VALUES
('VAL-0001', 1, DATE '2025-01-10', 'active'),
('VAL-0002', 1, DATE '2025-01-10', 'active'),
('VAL-0003', 2, DATE '2025-02-15', 'active'),
('VAL-0004', 3, DATE '2025-03-01', 'active'),
('VAL-0005', 4, DATE '2025-03-20', 'maintenance');

INSERT INTO e11_transfer_rule (rule_name, application_condition, starts_at, ends_at) VALUES
('90 минут', 'Повторная поездка в течение 90 минут', TIMESTAMPTZ '2026-01-01 00:00:00+03', NULL),
('Метро–наземный транспорт', 'Пересадка между метро и наземным транспортом', TIMESTAMPTZ '2026-01-01 00:00:00+03', NULL);

INSERT INTO e17_tariff_product_transfer_rule (tariff_product_id, transfer_rule_id, start_date, end_date) VALUES
(2, 1, DATE '2026-01-01', NULL),
(3, 1, DATE '2026-01-01', NULL),
(3, 2, DATE '2026-01-01', NULL);

INSERT INTO e6_card_product (card_id, tariff_product_id, activated_at, expires_at, remaining_trip_count, status) VALUES
(1, 2, TIMESTAMPTZ '2026-10-01 08:00:00+03', TIMESTAMPTZ '2027-01-01 00:00:00+03', 18, 'active'),
(2, 1, TIMESTAMPTZ '2026-10-20 09:00:00+03', TIMESTAMPTZ '2026-10-21 09:00:00+03', 0, 'used'),
(3, 3, TIMESTAMPTZ '2026-10-01 00:00:00+03', TIMESTAMPTZ '2026-10-31 23:59:59+03', NULL, 'active');

INSERT INTO e9_validation (card_id, validator_id, card_product_id, benefit_id, result, charged_amount, validated_at) VALUES
(1, 1, 1, 1, 'accepted', 0.00, TIMESTAMPTZ '2026-10-20 08:10:00+03'),
(1, 4, 1, 1, 'accepted', 0.00, TIMESTAMPTZ '2026-10-20 08:55:00+03'),
(2, 3, 2, NULL, 'accepted', 70.00, TIMESTAMPTZ '2026-10-20 09:20:00+03'),
(4, 2, NULL, NULL, 'rejected', 0.00, TIMESTAMPTZ '2026-10-20 10:05:00+03');

INSERT INTO e10_trip (card_id, validation_id, started_at, ended_at) VALUES
(1, 1, TIMESTAMPTZ '2026-10-20 08:10:00+03', TIMESTAMPTZ '2026-10-20 08:35:00+03'),
(1, 2, TIMESTAMPTZ '2026-10-20 08:55:00+03', TIMESTAMPTZ '2026-10-20 09:15:00+03'),
(2, 3, TIMESTAMPTZ '2026-10-20 09:20:00+03', TIMESTAMPTZ '2026-10-20 09:50:00+03');

INSERT INTO e12_transfer_chain (card_id, transfer_rule_id, started_at, ended_at) VALUES
(1, 1, TIMESTAMPTZ '2026-10-20 08:10:00+03', TIMESTAMPTZ '2026-10-20 09:15:00+03');

INSERT INTO e12_transfer_chain_trip (transfer_chain_id, trip_id, trip_order) VALUES
(1, 1, 1),
(1, 2, 2);

INSERT INTO e13_balance_operation (card_id, operation_type, amount, operation_at, status) VALUES
(1, 'deposit', 500.00, TIMESTAMPTZ '2026-10-19 18:00:00+03', 'completed'),
(2, 'withdrawal', 70.00, TIMESTAMPTZ '2026-10-20 09:20:00+03', 'completed'),
(1, 'compensation', 70.00, TIMESTAMPTZ '2026-10-21 12:00:00+03', 'completed');

INSERT INTO e14_appeal (owner_id, operator_id, reason, status, created_at, resolved_at) VALUES
(1, 1, 'Ошибочное списание стоимости поездки', 'resolved', TIMESTAMPTZ '2026-10-20 12:00:00+03', TIMESTAMPTZ '2026-10-21 11:50:00+03'),
(4, 2, 'Карта заблокирована валидатором', 'processing', TIMESTAMPTZ '2026-10-20 10:30:00+03', NULL);

INSERT INTO e17_balance_deposit (balance_operation_id, payment_method) VALUES
(1, 'bank_card');

INSERT INTO e18_balance_withdrawal (balance_operation_id, validation_id) VALUES
(2, 3);

INSERT INTO e15_compensation (balance_operation_id, appeal_id) VALUES
(3, 1);

INSERT INTO e3_card_reissue (old_card_id, new_card_id, operator_id, reissued_at, reissue_reason) VALUES
(1, 6, 1, TIMESTAMPTZ '2026-10-22 10:00:00+03', 'Замена повреждённой карты');

SELECT setval(pg_get_serial_sequence('e1_card_owner', 'owner_id'), (SELECT max(owner_id) FROM e1_card_owner));
SELECT setval(pg_get_serial_sequence('e2_card', 'card_id'), (SELECT max(card_id) FROM e2_card));
SELECT setval(pg_get_serial_sequence('e4_benefit', 'benefit_id'), (SELECT max(benefit_id) FROM e4_benefit));
SELECT setval(pg_get_serial_sequence('e5_tariff_product', 'tariff_product_id'), (SELECT max(tariff_product_id) FROM e5_tariff_product));
SELECT setval(pg_get_serial_sequence('e6_card_product', 'card_product_id'), (SELECT max(card_product_id) FROM e6_card_product));
SELECT setval(pg_get_serial_sequence('e7_transport_object', 'transport_object_id'), (SELECT max(transport_object_id) FROM e7_transport_object));
SELECT setval(pg_get_serial_sequence('e8_validator', 'validator_id'), (SELECT max(validator_id) FROM e8_validator));
SELECT setval(pg_get_serial_sequence('e9_validation', 'validation_id'), (SELECT max(validation_id) FROM e9_validation));
SELECT setval(pg_get_serial_sequence('e10_trip', 'trip_id'), (SELECT max(trip_id) FROM e10_trip));
SELECT setval(pg_get_serial_sequence('e11_transfer_rule', 'transfer_rule_id'), (SELECT max(transfer_rule_id) FROM e11_transfer_rule));
SELECT setval(pg_get_serial_sequence('e12_transfer_chain', 'transfer_chain_id'), (SELECT max(transfer_chain_id) FROM e12_transfer_chain));
SELECT setval(pg_get_serial_sequence('e13_balance_operation', 'balance_operation_id'), (SELECT max(balance_operation_id) FROM e13_balance_operation));
SELECT setval(pg_get_serial_sequence('e14_appeal', 'appeal_id'), (SELECT max(appeal_id) FROM e14_appeal));
SELECT setval(pg_get_serial_sequence('e16_employee_operator', 'operator_id'), (SELECT max(operator_id) FROM e16_employee_operator));

COMMIT;
