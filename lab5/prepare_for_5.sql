BEGIN;

SET search_path TO transport_card;

ALTER TABLE e9_validation
    ADD COLUMN IF NOT EXISTS device_event_number BIGINT,
    ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ;

WITH numbered_events AS (
    SELECT
        validation_id,
        ROW_NUMBER() OVER (
            PARTITION BY validator_id
            ORDER BY validated_at, validation_id
        ) AS event_number
    FROM e9_validation
)
UPDATE e9_validation AS validation
SET
    device_event_number = CASE
        WHEN numbered.event_number > 1
             AND numbered.event_number % 17 = 0
            THEN numbered.event_number - 1
        ELSE numbered.event_number
    END,
    received_at = validation.validated_at
        + make_interval(secs => 5 + (validation.validation_id % 120)::INTEGER)
FROM numbered_events AS numbered
WHERE numbered.validation_id = validation.validation_id
  AND (
      validation.device_event_number IS NULL
      OR validation.received_at IS NULL
  );

ALTER TABLE e9_validation
    ALTER COLUMN device_event_number SET NOT NULL,
    ALTER COLUMN received_at SET NOT NULL,
    DROP CONSTRAINT IF EXISTS ck_e9_received_after_validation,
    DROP CONSTRAINT IF EXISTS ck_e9_event_number;

ALTER TABLE e9_validation
    ADD CONSTRAINT ck_e9_received_after_validation
        CHECK (received_at >= validated_at),
    ADD CONSTRAINT ck_e9_event_number
        CHECK (device_event_number > 0);

ALTER TABLE e10_trip
    ADD COLUMN IF NOT EXISTS base_fare NUMERIC(12, 2);

UPDATE e10_trip AS trip
SET base_fare = validation.charged_amount
    + CASE WHEN trip.trip_id % 4 = 0 THEN 15.00 ELSE 0.00 END
FROM e9_validation AS validation
WHERE validation.validation_id = trip.validation_id
  AND trip.base_fare IS NULL;

ALTER TABLE e10_trip
    ALTER COLUMN base_fare SET NOT NULL,
    DROP CONSTRAINT IF EXISTS ck_e10_base_fare;

ALTER TABLE e10_trip
    ADD CONSTRAINT ck_e10_base_fare CHECK (base_fare >= 0);

ALTER TABLE e7_transport_object
    ADD COLUMN IF NOT EXISTS route_code VARCHAR(30);

UPDATE e7_transport_object
SET route_code = object_code
WHERE route_code IS NULL;

ALTER TABLE e7_transport_object
    ALTER COLUMN route_code SET NOT NULL,
    DROP CONSTRAINT IF EXISTS ck_e7_route_code;

ALTER TABLE e7_transport_object
    ADD CONSTRAINT ck_e7_route_code CHECK (btrim(route_code) <> '');

ALTER TABLE e11_transfer_rule
    ADD COLUMN IF NOT EXISTS max_transfer_minutes INTEGER,
    ADD COLUMN IF NOT EXISTS allowed_object_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS allowed_route_code VARCHAR(30);

UPDATE e11_transfer_rule
SET max_transfer_minutes = 90
WHERE max_transfer_minutes IS NULL;

ALTER TABLE e11_transfer_rule
    ALTER COLUMN max_transfer_minutes SET NOT NULL,
    DROP CONSTRAINT IF EXISTS ck_e11_max_transfer_minutes,
    DROP CONSTRAINT IF EXISTS ck_e11_allowed_object_type,
    DROP CONSTRAINT IF EXISTS ck_e11_allowed_route_code;

ALTER TABLE e11_transfer_rule
    ADD CONSTRAINT ck_e11_max_transfer_minutes
        CHECK (max_transfer_minutes > 0),
    ADD CONSTRAINT ck_e11_allowed_object_type
        CHECK (allowed_object_type IS NULL OR btrim(allowed_object_type) <> ''),
    ADD CONSTRAINT ck_e11_allowed_route_code
        CHECK (allowed_route_code IS NULL OR btrim(allowed_route_code) <> '');

ALTER TABLE e14_appeal
    ADD COLUMN IF NOT EXISTS card_id BIGINT;

UPDATE e14_appeal AS appeal
SET card_id = (
    SELECT card.card_id
    FROM e2_card AS card
    WHERE card.owner_id = appeal.owner_id
    ORDER BY card.issue_date DESC, card.card_id DESC
    LIMIT 1
)
WHERE appeal.card_id IS NULL;

ALTER TABLE e14_appeal
    DROP CONSTRAINT IF EXISTS fk_e14_appeal_card;

ALTER TABLE e14_appeal
    ADD CONSTRAINT fk_e14_appeal_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE e13_balance_operation
    DROP CONSTRAINT IF EXISTS ck_e13_operation_type;

ALTER TABLE e13_balance_operation
    ADD CONSTRAINT ck_e13_operation_type CHECK (
        operation_type IN (
            'deposit',
            'withdrawal',
            'compensation',
            'refund',
            'adjustment'
        )
    );

CREATE INDEX IF NOT EXISTS ix_e9_validator_event
    ON e9_validation (validator_id, device_event_number);

CREATE INDEX IF NOT EXISTS ix_e9_validator_received
    ON e9_validation (validator_id, received_at);

CREATE INDEX IF NOT EXISTS ix_e14_appeal_card_time
    ON e14_appeal (card_id, created_at);

COMMIT;
