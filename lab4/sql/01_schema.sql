BEGIN;

DROP SCHEMA IF EXISTS transport_card CASCADE;
CREATE SCHEMA transport_card;
SET search_path TO transport_card;

CREATE TABLE e1_card_owner (
    owner_id BIGINT GENERATED ALWAYS AS IDENTITY,
    passport_data VARCHAR(20) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20),
    email VARCHAR(254),
    CONSTRAINT pk_e1_card_owner PRIMARY KEY (owner_id),
    CONSTRAINT ak_e1_card_owner_passport UNIQUE (passport_data),
    CONSTRAINT ck_e1_owner_passport CHECK (btrim(passport_data) <> ''),
    CONSTRAINT ck_e1_owner_name CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_e1_owner_email CHECK (email IS NULL OR position('@' IN email) > 1)
);

CREATE TABLE e16_employee_operator (
    operator_id BIGINT GENERATED ALWAYS AS IDENTITY,
    passport_data VARCHAR(20) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    work_email VARCHAR(254) NOT NULL,
    CONSTRAINT pk_e16_employee_operator PRIMARY KEY (operator_id),
    CONSTRAINT ak_e16_operator_passport UNIQUE (passport_data),
    CONSTRAINT ak_e16_operator_email UNIQUE (work_email),
    CONSTRAINT ck_e16_operator_passport CHECK (btrim(passport_data) <> ''),
    CONSTRAINT ck_e16_operator_name CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_e16_operator_email CHECK (position('@' IN work_email) > 1)
);

CREATE TABLE e2_card (
    card_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_number VARCHAR(20) NOT NULL,
    owner_id BIGINT,
    issue_date DATE NOT NULL,
    validity_period_days INTEGER NOT NULL,
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_e2_card PRIMARY KEY (card_id),
    CONSTRAINT ak_e2_card_number UNIQUE (card_number),
    CONSTRAINT fk_e2_card_owner FOREIGN KEY (owner_id)
        REFERENCES e1_card_owner (owner_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT ck_e2_card_number CHECK (btrim(card_number) <> ''),
    CONSTRAINT ck_e2_card_validity CHECK (validity_period_days > 0),
    CONSTRAINT ck_e2_card_balance CHECK (current_balance >= 0),
    CONSTRAINT ck_e2_card_status CHECK (status IN ('active', 'blocked', 'expired', 'reissued'))
);

CREATE TABLE e4_benefit (
    benefit_id BIGINT GENERATED ALWAYS AS IDENTITY,
    owner_id BIGINT NOT NULL,
    benefit_type VARCHAR(50) NOT NULL,
    assignment_basis TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    CONSTRAINT pk_e4_benefit PRIMARY KEY (benefit_id),
    CONSTRAINT fk_e4_benefit_owner FOREIGN KEY (owner_id)
        REFERENCES e1_card_owner (owner_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_e4_benefit_type CHECK (btrim(benefit_type) <> ''),
    CONSTRAINT ck_e4_benefit_basis CHECK (btrim(assignment_basis) <> ''),
    CONSTRAINT ck_e4_benefit_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE e5_tariff_product (
    tariff_product_id BIGINT GENERATED ALWAYS AS IDENTITY,
    product_name VARCHAR(100) NOT NULL,
    trip_count INTEGER,
    price NUMERIC(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_e5_tariff_product PRIMARY KEY (tariff_product_id),
    CONSTRAINT ak_e5_product_name UNIQUE (product_name),
    CONSTRAINT ck_e5_product_name CHECK (btrim(product_name) <> ''),
    CONSTRAINT ck_e5_trip_count CHECK (trip_count IS NULL OR trip_count > 0),
    CONSTRAINT ck_e5_price CHECK (price >= 0),
    CONSTRAINT ck_e5_status CHECK (status IN ('active', 'archived'))
);

CREATE TABLE e7_transport_object (
    transport_object_id BIGINT GENERATED ALWAYS AS IDENTITY,
    object_code VARCHAR(30) NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    object_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_e7_transport_object PRIMARY KEY (transport_object_id),
    CONSTRAINT ak_e7_object_code UNIQUE (object_code),
    CONSTRAINT ck_e7_object_type CHECK (btrim(object_type) <> ''),
    CONSTRAINT ck_e7_object_name CHECK (btrim(object_name) <> ''),
    CONSTRAINT ck_e7_object_status CHECK (status IN ('active', 'inactive', 'maintenance'))
);

CREATE TABLE e8_validator (
    validator_id BIGINT GENERATED ALWAYS AS IDENTITY,
    validator_code VARCHAR(30) NOT NULL,
    transport_object_id BIGINT NOT NULL,
    installed_at DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_e8_validator PRIMARY KEY (validator_id),
    CONSTRAINT ak_e8_validator_code UNIQUE (validator_code),
    CONSTRAINT fk_e8_validator_object FOREIGN KEY (transport_object_id)
        REFERENCES e7_transport_object (transport_object_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e8_validator_status CHECK (status IN ('active', 'inactive', 'maintenance'))
);

CREATE TABLE e11_transfer_rule (
    transfer_rule_id BIGINT GENERATED ALWAYS AS IDENTITY,
    rule_name VARCHAR(100) NOT NULL,
    application_condition TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    CONSTRAINT pk_e11_transfer_rule PRIMARY KEY (transfer_rule_id),
    CONSTRAINT ak_e11_rule_name UNIQUE (rule_name),
    CONSTRAINT ck_e11_rule_condition CHECK (btrim(application_condition) <> ''),
    CONSTRAINT ck_e11_rule_dates CHECK (ends_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE e6_card_product (
    card_product_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_id BIGINT NOT NULL,
    tariff_product_id BIGINT NOT NULL,
    activated_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    remaining_trip_count INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_e6_card_product PRIMARY KEY (card_product_id),
    CONSTRAINT fk_e6_card_product_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_e6_card_product_tariff FOREIGN KEY (tariff_product_id)
        REFERENCES e5_tariff_product (tariff_product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e6_remaining_trips CHECK (remaining_trip_count IS NULL OR remaining_trip_count >= 0),
    CONSTRAINT ck_e6_product_dates CHECK (expires_at > activated_at),
    CONSTRAINT ck_e6_product_status CHECK (status IN ('active', 'used', 'expired', 'cancelled')),
    CONSTRAINT ak_e6_product_card_pair UNIQUE (card_product_id, card_id),
    CONSTRAINT ak_e6_card_product_activation UNIQUE (card_id, tariff_product_id, activated_at)
);

CREATE TABLE e17_tariff_product_transfer_rule (
    tariff_product_id BIGINT NOT NULL,
    transfer_rule_id BIGINT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    CONSTRAINT pk_e17_product_rule PRIMARY KEY (tariff_product_id, transfer_rule_id),
    CONSTRAINT fk_e17_product_rule_product FOREIGN KEY (tariff_product_id)
        REFERENCES e5_tariff_product (tariff_product_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_e17_product_rule_rule FOREIGN KEY (transfer_rule_id)
        REFERENCES e11_transfer_rule (transfer_rule_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_e17_product_rule_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE e9_validation (
    validation_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_id BIGINT NOT NULL,
    validator_id BIGINT NOT NULL,
    card_product_id BIGINT,
    benefit_id BIGINT,
    result VARCHAR(20) NOT NULL,
    charged_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    validated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_e9_validation PRIMARY KEY (validation_id),
    CONSTRAINT fk_e9_validation_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e9_validation_validator FOREIGN KEY (validator_id)
        REFERENCES e8_validator (validator_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e9_validation_product FOREIGN KEY (card_product_id, card_id)
        REFERENCES e6_card_product (card_product_id, card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e9_validation_benefit FOREIGN KEY (benefit_id)
        REFERENCES e4_benefit (benefit_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT ck_e9_validation_result CHECK (result IN ('accepted', 'rejected')),
    CONSTRAINT ck_e9_validation_amount CHECK (charged_amount >= 0),
    CONSTRAINT ak_e9_validation_card_pair UNIQUE (validation_id, card_id)
);

CREATE TABLE e10_trip (
    trip_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_id BIGINT NOT NULL,
    validation_id BIGINT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    CONSTRAINT pk_e10_trip PRIMARY KEY (trip_id),
    CONSTRAINT ak_e10_trip_validation UNIQUE (validation_id),
    CONSTRAINT fk_e10_trip_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e10_trip_validation FOREIGN KEY (validation_id, card_id)
        REFERENCES e9_validation (validation_id, card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e10_trip_dates CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE e12_transfer_chain (
    transfer_chain_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_id BIGINT NOT NULL,
    transfer_rule_id BIGINT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    CONSTRAINT pk_e12_transfer_chain PRIMARY KEY (transfer_chain_id),
    CONSTRAINT fk_e12_chain_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e12_chain_rule FOREIGN KEY (transfer_rule_id)
        REFERENCES e11_transfer_rule (transfer_rule_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e12_chain_dates CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE e12_transfer_chain_trip (
    transfer_chain_id BIGINT NOT NULL,
    trip_id BIGINT NOT NULL,
    trip_order SMALLINT NOT NULL,
    CONSTRAINT pk_e12_chain_trip PRIMARY KEY (transfer_chain_id, trip_id),
    CONSTRAINT ak_e12_chain_trip_order UNIQUE (transfer_chain_id, trip_order),
    CONSTRAINT ak_e12_trip_single_chain UNIQUE (trip_id),
    CONSTRAINT fk_e12_chain_trip_chain FOREIGN KEY (transfer_chain_id)
        REFERENCES e12_transfer_chain (transfer_chain_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_e12_chain_trip_trip FOREIGN KEY (trip_id)
        REFERENCES e10_trip (trip_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e12_chain_trip_order CHECK (trip_order > 0)
);

CREATE TABLE e13_balance_operation (
    balance_operation_id BIGINT GENERATED ALWAYS AS IDENTITY,
    card_id BIGINT NOT NULL,
    operation_type VARCHAR(20) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    operation_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed',
    CONSTRAINT pk_e13_balance_operation PRIMARY KEY (balance_operation_id),
    CONSTRAINT fk_e13_operation_card FOREIGN KEY (card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e13_operation_type CHECK (operation_type IN ('deposit', 'withdrawal', 'compensation')),
    CONSTRAINT ck_e13_operation_amount CHECK (amount > 0),
    CONSTRAINT ck_e13_operation_status CHECK (status IN ('pending', 'completed', 'cancelled'))
);

CREATE TABLE e14_appeal (
    appeal_id BIGINT GENERATED ALWAYS AS IDENTITY,
    owner_id BIGINT NOT NULL,
    operator_id BIGINT,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    CONSTRAINT pk_e14_appeal PRIMARY KEY (appeal_id),
    CONSTRAINT fk_e14_appeal_owner FOREIGN KEY (owner_id)
        REFERENCES e1_card_owner (owner_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e14_appeal_operator FOREIGN KEY (operator_id)
        REFERENCES e16_employee_operator (operator_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT ck_e14_appeal_reason CHECK (btrim(reason) <> ''),
    CONSTRAINT ck_e14_appeal_status CHECK (status IN ('new', 'processing', 'resolved', 'rejected')),
    CONSTRAINT ck_e14_appeal_dates CHECK (resolved_at IS NULL OR resolved_at >= created_at)
);

CREATE TABLE e15_compensation (
    balance_operation_id BIGINT,
    appeal_id BIGINT NOT NULL,
    CONSTRAINT pk_e15_compensation PRIMARY KEY (balance_operation_id),
    CONSTRAINT ak_e15_compensation_appeal UNIQUE (appeal_id),
    CONSTRAINT fk_e15_compensation_operation FOREIGN KEY (balance_operation_id)
        REFERENCES e13_balance_operation (balance_operation_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_e15_compensation_appeal FOREIGN KEY (appeal_id)
        REFERENCES e14_appeal (appeal_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE e17_balance_deposit (
    balance_operation_id BIGINT,
    payment_method VARCHAR(20) NOT NULL,
    CONSTRAINT pk_e17_balance_deposit PRIMARY KEY (balance_operation_id),
    CONSTRAINT fk_e17_deposit_operation FOREIGN KEY (balance_operation_id)
        REFERENCES e13_balance_operation (balance_operation_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_e17_payment_method CHECK (payment_method IN ('cash', 'bank_card', 'online'))
);

CREATE TABLE e18_balance_withdrawal (
    balance_operation_id BIGINT,
    validation_id BIGINT,
    CONSTRAINT pk_e18_balance_withdrawal PRIMARY KEY (balance_operation_id),
    CONSTRAINT fk_e18_withdrawal_operation FOREIGN KEY (balance_operation_id)
        REFERENCES e13_balance_operation (balance_operation_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_e18_withdrawal_validation FOREIGN KEY (validation_id)
        REFERENCES e9_validation (validation_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE e3_card_reissue (
    old_card_id BIGINT,
    new_card_id BIGINT NOT NULL,
    operator_id BIGINT NOT NULL,
    reissued_at TIMESTAMPTZ NOT NULL,
    reissue_reason TEXT NOT NULL,
    CONSTRAINT pk_e3_card_reissue PRIMARY KEY (old_card_id),
    CONSTRAINT ak_e3_new_card UNIQUE (new_card_id),
    CONSTRAINT fk_e3_old_card FOREIGN KEY (old_card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e3_new_card FOREIGN KEY (new_card_id)
        REFERENCES e2_card (card_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_e3_reissue_operator FOREIGN KEY (operator_id)
        REFERENCES e16_employee_operator (operator_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_e3_different_cards CHECK (old_card_id <> new_card_id),
    CONSTRAINT ck_e3_reissue_reason CHECK (btrim(reissue_reason) <> '')
);

CREATE INDEX ix_e2_card_owner ON e2_card (owner_id);
CREATE INDEX ix_e6_card_product_card ON e6_card_product (card_id);
CREATE INDEX ix_e9_validation_card_time ON e9_validation (card_id, validated_at);
CREATE INDEX ix_e10_trip_card_time ON e10_trip (card_id, started_at);
CREATE INDEX ix_e13_operation_card_time ON e13_balance_operation (card_id, operation_at);
CREATE INDEX ix_e14_appeal_owner ON e14_appeal (owner_id);

CREATE FUNCTION check_balance_operation_subtype()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    actual_type VARCHAR(20);
BEGIN
    SELECT operation_type
    INTO actual_type
    FROM e13_balance_operation
    WHERE balance_operation_id = NEW.balance_operation_id;

    IF actual_type IS DISTINCT FROM TG_ARGV[0] THEN
        RAISE EXCEPTION 'Операция % имеет тип %, ожидался тип %',
            NEW.balance_operation_id, actual_type, TG_ARGV[0];
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_e15_compensation_type
BEFORE INSERT OR UPDATE ON e15_compensation
FOR EACH ROW EXECUTE FUNCTION check_balance_operation_subtype('compensation');

CREATE TRIGGER tr_e17_deposit_type
BEFORE INSERT OR UPDATE ON e17_balance_deposit
FOR EACH ROW EXECUTE FUNCTION check_balance_operation_subtype('deposit');

CREATE TRIGGER tr_e18_withdrawal_type
BEFORE INSERT OR UPDATE ON e18_balance_withdrawal
FOR EACH ROW EXECUTE FUNCTION check_balance_operation_subtype('withdrawal');

CREATE FUNCTION protect_balance_operation_type()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM e15_compensation WHERE balance_operation_id = NEW.balance_operation_id)
       AND NEW.operation_type <> 'compensation' THEN
        RAISE EXCEPTION 'Операция % уже является компенсацией', NEW.balance_operation_id;
    END IF;

    IF EXISTS (SELECT 1 FROM e17_balance_deposit WHERE balance_operation_id = NEW.balance_operation_id)
       AND NEW.operation_type <> 'deposit' THEN
        RAISE EXCEPTION 'Операция % уже является внесением средств', NEW.balance_operation_id;
    END IF;

    IF EXISTS (SELECT 1 FROM e18_balance_withdrawal WHERE balance_operation_id = NEW.balance_operation_id)
       AND NEW.operation_type <> 'withdrawal' THEN
        RAISE EXCEPTION 'Операция % уже является списанием средств', NEW.balance_operation_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_e13_protect_operation_type
BEFORE UPDATE OF operation_type ON e13_balance_operation
FOR EACH ROW EXECUTE FUNCTION protect_balance_operation_type();

COMMIT;
