SET search_path TO transport_card;

BEGIN;


INSERT INTO e2_card (
    card_id,
    card_number,
    owner_id,
    issue_date,
    validity_period_days,
    current_balance,
    status
) OVERRIDING SYSTEM VALUE
VALUES (
    7,
    'T0000000007',
    1,
    DATE '2026-11-01',
    1825,
    120.00,
    'active'
)
ON CONFLICT DO NOTHING;

UPDATE e2_card
SET status = 'reissued'
WHERE card_id = 6;

INSERT INTO e3_card_reissue (
    old_card_id,
    new_card_id,
    operator_id,
    reissued_at,
    reissue_reason
)
VALUES (
    6,
    7,
    1,
    TIMESTAMPTZ '2026-11-01 10:00:00+03',
    'Повторная замена повреждённой карты'
)
ON CONFLICT DO NOTHING;

INSERT INTO e6_card_product (
    card_product_id,
    card_id,
    tariff_product_id,
    activated_at,
    expires_at,
    remaining_trip_count,
    status
) OVERRIDING SYSTEM VALUE
VALUES (
    9001,
    7,
    2,
    TIMESTAMPTZ '2026-07-01 00:00:00+03',
    TIMESTAMPTZ '2026-12-31 23:59:59+03',
    12,
    'active'
)
ON CONFLICT DO NOTHING;

UPDATE e11_transfer_rule
SET allowed_route_code = 'METRO-001'
WHERE transfer_rule_id = 1;


INSERT INTO e9_validation (
    validation_id,
    card_id,
    validator_id,
    card_product_id,
    benefit_id,
    result,
    charged_amount,
    validated_at,
    device_event_number,
    received_at
) OVERRIDING SYSTEM VALUE
VALUES
(90001, 7, 1, 9001, 1, 'accepted', 40.00,
 TIMESTAMPTZ '2026-08-10 08:00:00+03', 101,
 TIMESTAMPTZ '2026-08-10 08:00:08+03'),
(90002, 7, 1, 9001, 1, 'accepted', 30.00,
 TIMESTAMPTZ '2026-08-10 08:35:00+03', 102,
 TIMESTAMPTZ '2026-08-10 08:35:09+03'),
(90003, 7, 1, 9001, 1, 'accepted', 0.00,
 TIMESTAMPTZ '2026-08-10 08:35:00+03', 102,
 TIMESTAMPTZ '2026-08-10 08:36:20+03'),
(90004, 7, 1, 9001, 1, 'accepted', 35.00,
 TIMESTAMPTZ '2026-09-12 09:00:00+03', 103,
 TIMESTAMPTZ '2026-09-12 09:00:11+03'),
(90005, 7, 4, 9001, 1, 'accepted', 25.00,
 TIMESTAMPTZ '2026-09-12 09:40:00+03', 201,
 TIMESTAMPTZ '2026-09-12 09:40:17+03'),
(90006, 7, 1, 9001, 1, 'rejected', 0.00,
 TIMESTAMPTZ '2026-10-15 10:00:00+03', 104,
 TIMESTAMPTZ '2026-10-15 10:00:25+03'),
(90007, 7, 1, 9001, 1, 'accepted', 45.00,
 TIMESTAMPTZ '2026-10-16 10:00:00+03', 105,
 TIMESTAMPTZ '2026-10-16 10:00:12+03'),
(90008, 7, 4, 9001, 1, 'accepted', 20.00,
 TIMESTAMPTZ '2026-10-16 10:50:00+03', 202,
 TIMESTAMPTZ '2026-10-16 10:50:16+03'),
(90009, 2, 3, 2, NULL, 'accepted', 70.00,
 TIMESTAMPTZ '2026-11-01 09:00:00+03', 301,
 TIMESTAMPTZ '2026-11-01 09:00:14+03')
ON CONFLICT DO NOTHING;

INSERT INTO e10_trip (
    trip_id,
    card_id,
    validation_id,
    started_at,
    ended_at,
    base_fare
) OVERRIDING SYSTEM VALUE
VALUES
(91001, 7, 90001, TIMESTAMPTZ '2026-08-10 08:00:00+03',
 TIMESTAMPTZ '2026-08-10 08:25:00+03', 70.00),
(91002, 7, 90002, TIMESTAMPTZ '2026-08-10 08:35:00+03',
 TIMESTAMPTZ '2026-08-10 08:55:00+03', 70.00),
(91003, 7, 90004, TIMESTAMPTZ '2026-09-12 09:00:00+03',
 TIMESTAMPTZ '2026-09-12 09:25:00+03', 70.00),
(91004, 7, 90005, TIMESTAMPTZ '2026-09-12 09:40:00+03',
 TIMESTAMPTZ '2026-09-12 10:05:00+03', 70.00),
(91005, 7, 90007, TIMESTAMPTZ '2026-10-16 10:00:00+03',
 TIMESTAMPTZ '2026-10-16 10:30:00+03', 70.00),
(91006, 7, 90008, TIMESTAMPTZ '2026-10-16 10:50:00+03',
 TIMESTAMPTZ '2026-10-16 11:10:00+03', 70.00)
ON CONFLICT DO NOTHING;

INSERT INTO e12_transfer_chain (
    transfer_chain_id,
    card_id,
    transfer_rule_id,
    started_at,
    ended_at
) OVERRIDING SYSTEM VALUE
VALUES
(92001, 7, 1, TIMESTAMPTZ '2026-08-10 08:00:00+03',
 TIMESTAMPTZ '2026-08-10 08:55:00+03'),
(92002, 7, 1, TIMESTAMPTZ '2026-09-12 09:00:00+03',
 TIMESTAMPTZ '2026-09-12 10:05:00+03'),
(92003, 7, 1, TIMESTAMPTZ '2026-10-16 10:00:00+03',
 TIMESTAMPTZ '2026-10-16 11:10:00+03')
ON CONFLICT DO NOTHING;

INSERT INTO e12_transfer_chain_trip (
    transfer_chain_id,
    trip_id,
    trip_order
)
VALUES
(92001, 91001, 1),
(92001, 91002, 2),
(92002, 91003, 1),
(92002, 91004, 2),
(92003, 91005, 1),
(92003, 91006, 2)
ON CONFLICT DO NOTHING;

INSERT INTO e13_balance_operation (
    balance_operation_id,
    card_id,
    operation_type,
    amount,
    operation_at,
    status
) OVERRIDING SYSTEM VALUE
VALUES
(93001, 7, 'deposit',      100.00, TIMESTAMPTZ '2026-08-01 12:00:00+03', 'completed'),
(93002, 7, 'withdrawal',   200.00, TIMESTAMPTZ '2026-08-10 08:00:00+03', 'completed'),
(93003, 7, 'deposit',      500.00, TIMESTAMPTZ '2026-09-01 12:00:00+03', 'completed'),
(93004, 7, 'withdrawal',   100.00, TIMESTAMPTZ '2026-09-12 09:00:00+03', 'completed'),
(93005, 7, 'compensation',  20.00, TIMESTAMPTZ '2026-09-15 15:00:00+03', 'completed'),
(93006, 7, 'withdrawal',   300.00, TIMESTAMPTZ '2026-10-16 10:00:00+03', 'completed'),
(93007, 7, 'refund',        50.00, TIMESTAMPTZ '2026-10-18 11:00:00+03', 'completed'),
(93008, 7, 'adjustment',    10.00, TIMESTAMPTZ '2026-10-19 11:00:00+03', 'completed'),
(93009, 7, 'compensation',  40.00, TIMESTAMPTZ '2026-10-20 15:00:00+03', 'completed')
ON CONFLICT DO NOTHING;

INSERT INTO e14_appeal (
    appeal_id,
    owner_id,
    card_id,
    operator_id,
    reason,
    status,
    created_at,
    resolved_at
) OVERRIDING SYSTEM VALUE
VALUES
(94001, 1, 7, 1, 'Ошибочное списание стоимости поездки', 'resolved',
 TIMESTAMPTZ '2026-09-14 12:00:00+03',
 TIMESTAMPTZ '2026-09-15 14:00:00+03'),
(94002, 1, 7, 1, 'Ошибочное повторное списание', 'resolved',
 TIMESTAMPTZ '2026-10-19 12:00:00+03',
 TIMESTAMPTZ '2026-10-20 14:00:00+03')
ON CONFLICT DO NOTHING;

INSERT INTO e17_balance_deposit (balance_operation_id, payment_method)
VALUES
(93001, 'bank_card'),
(93003, 'online')
ON CONFLICT DO NOTHING;

INSERT INTO e18_balance_withdrawal (balance_operation_id, validation_id)
VALUES
(93002, 90001),
(93004, 90004),
(93006, 90007)
ON CONFLICT DO NOTHING;

INSERT INTO e15_compensation (balance_operation_id, appeal_id)
VALUES
(93005, 94001),
(93009, 94002)
ON CONFLICT DO NOTHING;

SELECT setval(
    pg_get_serial_sequence('e2_card', 'card_id'),
    (SELECT MAX(card_id) FROM e2_card)
);
SELECT setval(
    pg_get_serial_sequence('e6_card_product', 'card_product_id'),
    (SELECT MAX(card_product_id) FROM e6_card_product)
);
SELECT setval(
    pg_get_serial_sequence('e9_validation', 'validation_id'),
    (SELECT MAX(validation_id) FROM e9_validation)
);
SELECT setval(
    pg_get_serial_sequence('e10_trip', 'trip_id'),
    (SELECT MAX(trip_id) FROM e10_trip)
);
SELECT setval(
    pg_get_serial_sequence('e12_transfer_chain', 'transfer_chain_id'),
    (SELECT MAX(transfer_chain_id) FROM e12_transfer_chain)
);
SELECT setval(
    pg_get_serial_sequence('e13_balance_operation', 'balance_operation_id'),
    (SELECT MAX(balance_operation_id) FROM e13_balance_operation)
);
SELECT setval(
    pg_get_serial_sequence('e14_appeal', 'appeal_id'),
    (SELECT MAX(appeal_id) FROM e14_appeal)
);

COMMIT;
