SET search_path TO transport_card;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'transport_card'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT 'e1_card_owner' AS table_name, count(*) AS row_count FROM e1_card_owner
UNION ALL SELECT 'e2_card', count(*) FROM e2_card
UNION ALL SELECT 'e3_card_reissue', count(*) FROM e3_card_reissue
UNION ALL SELECT 'e4_benefit', count(*) FROM e4_benefit
UNION ALL SELECT 'e5_tariff_product', count(*) FROM e5_tariff_product
UNION ALL SELECT 'e6_card_product', count(*) FROM e6_card_product
UNION ALL SELECT 'e7_transport_object', count(*) FROM e7_transport_object
UNION ALL SELECT 'e8_validator', count(*) FROM e8_validator
UNION ALL SELECT 'e9_validation', count(*) FROM e9_validation
UNION ALL SELECT 'e10_trip', count(*) FROM e10_trip
UNION ALL SELECT 'e11_transfer_rule', count(*) FROM e11_transfer_rule
UNION ALL SELECT 'e12_transfer_chain', count(*) FROM e12_transfer_chain
UNION ALL SELECT 'e12_transfer_chain_trip', count(*) FROM e12_transfer_chain_trip
UNION ALL SELECT 'e13_balance_operation', count(*) FROM e13_balance_operation
UNION ALL SELECT 'e14_appeal', count(*) FROM e14_appeal
UNION ALL SELECT 'e15_compensation', count(*) FROM e15_compensation
UNION ALL SELECT 'e16_employee_operator', count(*) FROM e16_employee_operator
UNION ALL SELECT 'e17_tariff_product_transfer_rule', count(*) FROM e17_tariff_product_transfer_rule
UNION ALL SELECT 'e17_balance_deposit', count(*) FROM e17_balance_deposit
UNION ALL SELECT 'e18_balance_withdrawal', count(*) FROM e18_balance_withdrawal
ORDER BY table_name;

SELECT c.card_number, o.full_name, c.current_balance, c.status
FROM e2_card AS c
LEFT JOIN e1_card_owner AS o ON o.owner_id = c.owner_id
ORDER BY c.card_id
LIMIT 20;

SELECT v.validation_id, c.card_number, vr.validator_code, v.result, v.charged_amount, v.validated_at
FROM e9_validation AS v
JOIN e2_card AS c ON c.card_id = v.card_id
JOIN e8_validator AS vr ON vr.validator_id = v.validator_id
ORDER BY v.validated_at DESC
LIMIT 20;

SELECT conrelid::regclass AS table_name, conname AS constraint_name, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'transport_card'::regnamespace
ORDER BY conrelid::regclass::text, conname;
