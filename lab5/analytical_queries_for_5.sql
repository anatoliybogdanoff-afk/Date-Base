SET search_path TO transport_card;

/*
Первый запрос 
*/
WITH RECURSIVE card_chain AS (
    SELECT
        card.card_id AS root_card_id,
        card.card_id,
        card.owner_id,
        0 AS reissue_level,
        ARRAY[card.card_id] AS path_ids
    FROM e2_card AS card
    WHERE NOT EXISTS (
        SELECT 1
        FROM e3_card_reissue AS reissue
        WHERE reissue.new_card_id = card.card_id
    )

    UNION ALL

    SELECT
        chain.root_card_id,
        reissue.new_card_id,
        COALESCE(new_card.owner_id, chain.owner_id),
        chain.reissue_level + 1,
        chain.path_ids || reissue.new_card_id
    FROM card_chain AS chain
    JOIN e3_card_reissue AS reissue
        ON reissue.old_card_id = chain.card_id
    JOIN e2_card AS new_card
        ON new_card.card_id = reissue.new_card_id
    WHERE NOT reissue.new_card_id = ANY(chain.path_ids)
),
chain_summary AS (
    SELECT
        chain.root_card_id,
        MIN(chain.owner_id) AS owner_id,
        COUNT(*) AS issued_card_count,
        COUNT(*) - 1 AS reissue_count,
        SUM(card.current_balance) AS current_chain_balance
    FROM card_chain AS chain
    JOIN e2_card AS card
        ON card.card_id = chain.card_id
    GROUP BY chain.root_card_id
    HAVING COUNT(*) - 1 >= 2
),
validation_summary AS (
    SELECT
        chain.root_card_id,
        COUNT(validation.validation_id) FILTER (
            WHERE validation.result = 'accepted'
        ) AS successful_validation_count,
        COALESCE(SUM(validation.charged_amount) FILTER (
            WHERE validation.result = 'accepted'
        ), 0) AS charged_amount
    FROM card_chain AS chain
    LEFT JOIN e9_validation AS validation
        ON validation.card_id = chain.card_id
    GROUP BY chain.root_card_id
),
operation_summary AS (
    SELECT
        chain.root_card_id,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'deposit'
              AND operation.status = 'completed'
        ), 0) AS deposit_amount,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'compensation'
              AND operation.status = 'completed'
        ), 0) AS compensation_amount
    FROM card_chain AS chain
    LEFT JOIN e13_balance_operation AS operation
        ON operation.card_id = chain.card_id
    GROUP BY chain.root_card_id
)
SELECT
    owner.owner_id,
    owner.full_name,
    summary.root_card_id,
    summary.issued_card_count,
    summary.reissue_count,
    COALESCE(validation.successful_validation_count, 0)
        AS successful_validation_count,
    COALESCE(validation.charged_amount, 0) AS charged_amount,
    COALESCE(operation.deposit_amount, 0) AS deposit_amount,
    COALESCE(operation.compensation_amount, 0) AS compensation_amount,
    summary.current_chain_balance
FROM chain_summary AS summary
JOIN e1_card_owner AS owner
    ON owner.owner_id = summary.owner_id
LEFT JOIN validation_summary AS validation
    ON validation.root_card_id = summary.root_card_id
LEFT JOIN operation_summary AS operation
    ON operation.root_card_id = summary.root_card_id
ORDER BY charged_amount DESC, owner.owner_id, summary.root_card_id;


/*
Второй запрос 
*/
WITH month_bounds AS (
    SELECT
        date_trunc('month', MIN(received_at)) AS first_month,
        date_trunc('month', MAX(received_at)) AS last_month
    FROM e9_validation
),
months AS (
    SELECT generate_series(
        first_month,
        last_month,
        INTERVAL '1 month'
    ) AS report_month
    FROM month_bounds
    WHERE first_month IS NOT NULL
),
validator_months AS (
    SELECT
        validator.validator_id,
        validator.validator_code,
        months.report_month
    FROM e8_validator AS validator
    CROSS JOIN months
),
marked_events AS (
    SELECT
        validation.validation_id,
        validation.validator_id,
        validation.device_event_number,
        validation.result,
        validation.validated_at,
        validation.received_at,
        date_trunc('month', validation.received_at) AS report_month,
        ROW_NUMBER() OVER (
            PARTITION BY
                validation.validator_id,
                validation.device_event_number
            ORDER BY
                validation.received_at,
                validation.validation_id
        ) AS transmission_number
    FROM e9_validation AS validation
),
missing_months AS (
    SELECT
        matrix.validator_id,
        matrix.report_month
    FROM validator_months AS matrix
    LEFT JOIN marked_events AS event
        ON event.validator_id = matrix.validator_id
       AND event.report_month = matrix.report_month
    WHERE event.validation_id IS NULL
),
monthly_statistics AS (
    SELECT
        matrix.validator_id,
        matrix.validator_code,
        matrix.report_month,
        COUNT(event.validation_id) AS received_event_count,
        COUNT(event.validation_id) FILTER (
            WHERE event.transmission_number = 1
        ) AS unique_validation_count,
        COUNT(event.validation_id) FILTER (
            WHERE event.transmission_number > 1
        ) AS repeated_event_count,
        COUNT(event.validation_id) FILTER (
            WHERE event.result = 'rejected'
        ) AS rejected_event_count,
        ROUND(AVG(EXTRACT(EPOCH FROM
            (event.received_at - event.validated_at)))::NUMERIC, 2)
            AS average_sync_delay_seconds,
        ROUND(
            100.0 * COUNT(event.validation_id) FILTER (
                WHERE event.result = 'rejected'
            ) / NULLIF(COUNT(event.validation_id), 0),
            2
        ) AS rejection_percentage
    FROM validator_months AS matrix
    LEFT JOIN marked_events AS event
        ON event.validator_id = matrix.validator_id
       AND event.report_month = matrix.report_month
    GROUP BY
        matrix.validator_id,
        matrix.validator_code,
        matrix.report_month
),
with_previous_month AS (
    SELECT
        statistics.*,
        LAG(statistics.rejection_percentage) OVER (
            PARTITION BY statistics.validator_id
            ORDER BY statistics.report_month
        ) AS previous_rejection_percentage
    FROM monthly_statistics AS statistics
)
SELECT
    previous.*,
    missing.validator_id IS NOT NULL AS month_without_events,
    previous.rejection_percentage
        - previous.previous_rejection_percentage
        AS rejection_percentage_change,
    DENSE_RANK() OVER (
        PARTITION BY previous.report_month
        ORDER BY
            previous.rejection_percentage DESC NULLS LAST,
            previous.repeated_event_count DESC
    ) AS validator_rank
FROM with_previous_month AS previous
LEFT JOIN missing_months AS missing
    ON missing.validator_id = previous.validator_id
   AND missing.report_month = previous.report_month
ORDER BY
    previous.report_month,
    validator_rank,
    previous.validator_id;


/*
Третий запрос
*/
WITH trip_details AS (
    SELECT
        product.tariff_product_id,
        product.product_name,
        date_trunc('month', trip.started_at) AS report_month,
        trip.trip_id,
        composition.transfer_chain_id,
        validation.charged_amount,
        trip.base_fare,
        CASE
            WHEN composition.transfer_chain_id IS NULL THEN FALSE
            WHEN relation.tariff_product_id IS NULL THEN FALSE
            WHEN trip.started_at < chain.started_at THEN FALSE
            WHEN chain.ended_at IS NOT NULL
                 AND trip.started_at > chain.ended_at THEN FALSE
            WHEN trip.started_at < rule.starts_at THEN FALSE
            WHEN rule.ends_at IS NOT NULL
                 AND trip.started_at > rule.ends_at THEN FALSE
            WHEN relation.start_date > trip.started_at::DATE THEN FALSE
            WHEN relation.end_date IS NOT NULL
                 AND relation.end_date < trip.started_at::DATE THEN FALSE
            WHEN COALESCE(chain.ended_at, trip.ended_at, trip.started_at)
                 > chain.started_at
                    + make_interval(mins => rule.max_transfer_minutes)
                THEN FALSE
            WHEN rule.allowed_object_type IS NOT NULL
                 AND object.object_type <> rule.allowed_object_type THEN FALSE
            WHEN rule.allowed_route_code IS NOT NULL
                 AND object.route_code <> rule.allowed_route_code THEN FALSE
            ELSE TRUE
        END AS valid_transfer
    FROM e10_trip AS trip
    JOIN e9_validation AS validation
        ON validation.validation_id = trip.validation_id
       AND validation.card_id = trip.card_id
    JOIN e6_card_product AS card_product
        ON card_product.card_product_id = validation.card_product_id
       AND card_product.card_id = validation.card_id
    JOIN e5_tariff_product AS product
        ON product.tariff_product_id = card_product.tariff_product_id
    JOIN e8_validator AS validator
        ON validator.validator_id = validation.validator_id
    JOIN e7_transport_object AS object
        ON object.transport_object_id = validator.transport_object_id
    LEFT JOIN e12_transfer_chain_trip AS composition
        ON composition.trip_id = trip.trip_id
    LEFT JOIN e12_transfer_chain AS chain
        ON chain.transfer_chain_id = composition.transfer_chain_id
    LEFT JOIN e11_transfer_rule AS rule
        ON rule.transfer_rule_id = chain.transfer_rule_id
    LEFT JOIN e17_tariff_product_transfer_rule AS relation
        ON relation.tariff_product_id = product.tariff_product_id
       AND relation.transfer_rule_id = chain.transfer_rule_id
),
monthly_trip_statistics AS (
    SELECT
        details.tariff_product_id,
        details.product_name,
        details.report_month,
        COUNT(DISTINCT details.trip_id) AS trip_count,
        COALESCE(SUM(details.charged_amount), 0) AS charged_amount,
        COALESCE(SUM(GREATEST(
            details.base_fare - details.charged_amount,
            0
        )), 0) AS saved_amount,
        ROUND(
            100.0 * COUNT(DISTINCT details.trip_id) FILTER (
                WHERE details.valid_transfer
            ) / NULLIF(COUNT(DISTINCT details.trip_id), 0),
            2
        ) AS transfer_trip_percentage
    FROM trip_details AS details
    GROUP BY
        details.tariff_product_id,
        details.product_name,
        details.report_month
),
chain_details AS (
    SELECT
        details.tariff_product_id,
        details.product_name,
        MIN(details.report_month) AS report_month,
        details.transfer_chain_id,
        COUNT(DISTINCT details.trip_id) AS validation_count,
        BOOL_AND(details.valid_transfer) AS valid_chain
    FROM trip_details AS details
    WHERE details.transfer_chain_id IS NOT NULL
    GROUP BY
        details.tariff_product_id,
        details.product_name,
        details.transfer_chain_id
),
monthly_chain_statistics AS (
    SELECT
        chain.tariff_product_id,
        chain.product_name,
        chain.report_month,
        COUNT(*) FILTER (
            WHERE chain.valid_chain
        ) AS transfer_chain_count,
        ROUND(AVG(chain.validation_count) FILTER (
            WHERE chain.valid_chain
        ), 2) AS average_validations_in_chain
    FROM chain_details AS chain
    GROUP BY
        chain.tariff_product_id,
        chain.product_name,
        chain.report_month
),
monthly_statistics AS (
    SELECT
        trips.*,
        COALESCE(chains.transfer_chain_count, 0) AS transfer_chain_count,
        chains.average_validations_in_chain
    FROM monthly_trip_statistics AS trips
    LEFT JOIN monthly_chain_statistics AS chains
        ON chains.tariff_product_id = trips.tariff_product_id
       AND chains.report_month = trips.report_month
),
with_previous_month AS (
    SELECT
        statistics.*,
        LAG(statistics.transfer_trip_percentage) OVER (
            PARTITION BY statistics.tariff_product_id
            ORDER BY statistics.report_month
        ) AS previous_transfer_trip_percentage
    FROM monthly_statistics AS statistics
)
SELECT
    previous.*,
    previous.transfer_trip_percentage
        - previous.previous_transfer_trip_percentage
        AS transfer_share_change,
    SUM(previous.saved_amount) OVER (
        PARTITION BY previous.tariff_product_id
        ORDER BY previous.report_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS saved_amount_for_three_rows
FROM with_previous_month AS previous
ORDER BY previous.tariff_product_id, previous.report_month;


/*
Четвертый запрос
*/
WITH ordered_validations AS (
    SELECT
        validation.validation_id,
        validation.result,
        validation.charged_amount,
        validation.validated_at,
        validation.card_product_id,
        product.tariff_product_id,
        product.product_name,
        product.trip_count,
        card_product.activated_at,
        card_product.expires_at,
        benefit.benefit_id,
        benefit.benefit_type,
        benefit.start_date AS benefit_start_date,
        benefit.end_date AS benefit_end_date,
        COUNT(*) FILTER (
            WHERE validation.result = 'accepted'
        ) OVER (
            PARTITION BY validation.card_product_id
            ORDER BY validation.validated_at, validation.validation_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_successful_validation_count
    FROM e9_validation AS validation
    JOIN e6_card_product AS card_product
        ON card_product.card_product_id = validation.card_product_id
       AND card_product.card_id = validation.card_id
    JOIN e5_tariff_product AS product
        ON product.tariff_product_id = card_product.tariff_product_id
    LEFT JOIN e4_benefit AS benefit
        ON benefit.benefit_id = validation.benefit_id
),
validation_checks AS (
    SELECT
        COALESCE(ordered.benefit_type, 'Без льготы') AS benefit_type,
        ordered.tariff_product_id,
        ordered.product_name,
        ordered.validation_id,
        ordered.result,
        ordered.charged_amount,
        ordered.benefit_id IS NOT NULL
            AND (
                ordered.validated_at::DATE < ordered.benefit_start_date
                OR (
                    ordered.benefit_end_date IS NOT NULL
                    AND ordered.validated_at::DATE > ordered.benefit_end_date
                )
            ) AS invalid_benefit,
        ordered.validated_at < ordered.activated_at
            OR ordered.validated_at > ordered.expires_at
            AS expired_product,
        ordered.trip_count IS NOT NULL
            AND ordered.previous_successful_validation_count
                >= ordered.trip_count
            AS exceeded_trip_limit
    FROM ordered_validations AS ordered
),
benefit_product_statistics AS (
    SELECT
        checks.benefit_type,
        checks.tariff_product_id,
        checks.product_name,
        COUNT(*) FILTER (
            WHERE checks.result = 'accepted'
        ) AS successful_validation_count,
        COALESCE(SUM(checks.charged_amount) FILTER (
            WHERE checks.result = 'accepted'
        ), 0) AS charged_amount,
        ROUND(AVG(checks.charged_amount) FILTER (
            WHERE checks.result = 'accepted'
        ), 2) AS average_trip_cost,
        COUNT(*) FILTER (
            WHERE checks.invalid_benefit
        ) AS invalid_benefit_count,
        COUNT(*) FILTER (
            WHERE checks.expired_product
        ) AS expired_product_count,
        COUNT(*) FILTER (
            WHERE checks.exceeded_trip_limit
        ) AS exceeded_limit_count,
        COUNT(*) FILTER (
            WHERE checks.invalid_benefit
               OR checks.expired_product
               OR checks.exceeded_trip_limit
        ) AS violation_count,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE checks.invalid_benefit
                   OR checks.expired_product
                   OR checks.exceeded_trip_limit
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS violation_percentage
    FROM validation_checks AS checks
    GROUP BY
        checks.benefit_type,
        checks.tariff_product_id,
        checks.product_name
),
product_violation_statistics AS (
    SELECT
        checks.tariff_product_id,
        COUNT(*) FILTER (
            WHERE checks.invalid_benefit
               OR checks.expired_product
               OR checks.exceeded_trip_limit
        ) AS violation_count,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE checks.invalid_benefit
                   OR checks.expired_product
                   OR checks.exceeded_trip_limit
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS violation_percentage
    FROM validation_checks AS checks
    GROUP BY checks.tariff_product_id
),
product_ranking AS (
    SELECT
        product_statistics.*,
        DENSE_RANK() OVER (
            ORDER BY
                product_statistics.violation_percentage DESC,
                product_statistics.violation_count DESC
        ) AS violation_rank
    FROM product_violation_statistics AS product_statistics
)
SELECT
    statistics.*,
    ranking.violation_rank
FROM benefit_product_statistics AS statistics
JOIN product_ranking AS ranking
    ON ranking.tariff_product_id = statistics.tariff_product_id
ORDER BY
    ranking.violation_rank,
    statistics.tariff_product_id,
    statistics.benefit_type;


/*
Пятый запрос
*/
WITH operation_months AS (
    SELECT
        operation.card_id,
        date_trunc('month', operation.operation_at) AS report_month,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'deposit'
              AND operation.status = 'completed'
        ), 0) AS deposit_amount,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'withdrawal'
              AND operation.status = 'completed'
        ), 0) AS withdrawal_amount,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'refund'
              AND operation.status = 'completed'
        ), 0) AS refund_amount,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'adjustment'
              AND operation.status = 'completed'
        ), 0) AS adjustment_amount,
        COALESCE(SUM(operation.amount) FILTER (
            WHERE operation.operation_type = 'compensation'
              AND operation.status = 'completed'
        ), 0) AS compensation_amount
    FROM e13_balance_operation AS operation
    GROUP BY
        operation.card_id,
        date_trunc('month', operation.operation_at)
),
appeal_months AS (
    SELECT
        appeal.card_id,
        date_trunc('month', appeal.created_at) AS report_month,
        COUNT(*) FILTER (
            WHERE appeal.reason ILIKE '%ошиб%спис%'
               OR appeal.reason ILIKE '%incorrect%charg%'
        ) AS incorrect_charge_appeal_count
    FROM e14_appeal AS appeal
    WHERE appeal.card_id IS NOT NULL
    GROUP BY
        appeal.card_id,
        date_trunc('month', appeal.created_at)
),
card_months AS (
    SELECT card_id, report_month FROM operation_months
    UNION
    SELECT card_id, report_month FROM appeal_months
),
monthly_balance AS (
    SELECT
        month.card_id,
        month.report_month,
        COALESCE(operation.deposit_amount, 0) AS deposit_amount,
        COALESCE(operation.withdrawal_amount, 0) AS withdrawal_amount,
        COALESCE(operation.refund_amount, 0) AS refund_amount,
        COALESCE(operation.adjustment_amount, 0) AS adjustment_amount,
        COALESCE(operation.compensation_amount, 0) AS compensation_amount,
        COALESCE(appeal.incorrect_charge_appeal_count, 0)
            AS incorrect_charge_appeal_count,
        COALESCE(operation.deposit_amount, 0)
            - COALESCE(operation.withdrawal_amount, 0)
            + COALESCE(operation.refund_amount, 0)
            + COALESCE(operation.adjustment_amount, 0)
            + COALESCE(operation.compensation_amount, 0)
            AS monthly_balance_change,
        ROUND(
            100.0 * COALESCE(operation.compensation_amount, 0)
            / NULLIF(COALESCE(operation.withdrawal_amount, 0), 0),
            2
        ) AS compensated_withdrawal_percentage
    FROM card_months AS month
    LEFT JOIN operation_months AS operation
        ON operation.card_id = month.card_id
       AND operation.report_month = month.report_month
    LEFT JOIN appeal_months AS appeal
        ON appeal.card_id = month.card_id
       AND appeal.report_month = month.report_month
),
balance_dynamics AS (
    SELECT
        monthly.*,
        SUM(monthly.monthly_balance_change) OVER (
            PARTITION BY monthly.card_id
            ORDER BY monthly.report_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS calculated_balance,
        LAG(monthly.monthly_balance_change) OVER (
            PARTITION BY monthly.card_id
            ORDER BY monthly.report_month
        ) AS previous_month_change
    FROM monthly_balance AS monthly
)
SELECT
    card.card_number,
    dynamics.*,
    dynamics.monthly_balance_change
        - dynamics.previous_month_change
        AS change_from_previous_month
FROM balance_dynamics AS dynamics
JOIN e2_card AS card
    ON card.card_id = dynamics.card_id
WHERE dynamics.calculated_balance < 0
   OR dynamics.compensation_amount
        > dynamics.withdrawal_amount * 0.10
ORDER BY dynamics.card_id, dynamics.report_month;
