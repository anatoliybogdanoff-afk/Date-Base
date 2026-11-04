from __future__ import annotations

import argparse
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path


MOSCOW_TZ = timezone(timedelta(hours=3))


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_timestamp(value: datetime) -> str:
    return "TIMESTAMPTZ " + sql_text(value.isoformat(sep=" "))


def write_insert(file, table: str, columns: list[str], rows: list[tuple], override: bool = False) -> None:
    if not rows:
        return
    file.write(f"INSERT INTO {table} ({', '.join(columns)})")
    if override:
        file.write(" OVERRIDING SYSTEM VALUE")
    file.write(" VALUES\n")
    rendered_rows = []
    for row in rows:
        rendered_rows.append("(" + ", ".join(str(value) for value in row) + ")")
    file.write(",\n".join(rendered_rows))
    file.write(";\n\n")


def generate(output_path: Path, seed: int) -> None:
    rng = random.Random(seed)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    owner_ids = list(range(1001, 1051))
    card_ids = list(range(2001, 2081))
    product_record_ids = list(range(3001, 3081))

    first_names = ["Анна", "Мария", "Елена", "Ольга", "Иван", "Павел", "Олег", "Максим"]
    last_names = ["Иванова", "Петрова", "Соколова", "Волкова", "Смирнов", "Орлов", "Крылов", "Белов"]

    owners = []
    for index, owner_id in enumerate(owner_ids, start=1):
        full_name = f"{rng.choice(first_names)} {rng.choice(last_names)}"
        owners.append((
            owner_id,
            sql_text(f"77{index:02d} {500000 + index}"),
            sql_text(full_name),
            sql_text(f"+7900100{index:04d}"),
            sql_text(f"generated{index}@example.ru"),
        ))

    cards = []
    card_products = []
    for index, card_id in enumerate(card_ids):
        owner_id = rng.choice(owner_ids)
        issue_date = datetime(2025, 1, 1, tzinfo=MOSCOW_TZ) + timedelta(days=rng.randint(0, 600))
        balance = rng.randint(0, 5000)
        cards.append((
            card_id,
            sql_text(f"TG{card_id:010d}"),
            owner_id,
            f"DATE {sql_text(issue_date.date().isoformat())}",
            1825,
            f"{balance:.2f}",
            sql_text("active"),
        ))

        card_product_id = product_record_ids[index]
        tariff_product_id = rng.choice([1, 2, 3])
        activated = datetime(2026, 10, 1, 0, 0, tzinfo=MOSCOW_TZ) + timedelta(days=rng.randint(0, 15))
        expires = activated + timedelta(days=30 if tariff_product_id == 3 else 90)
        remaining = "NULL" if tariff_product_id == 3 else rng.randint(1, 20)
        card_products.append((
            card_product_id,
            card_id,
            tariff_product_id,
            sql_timestamp(activated),
            sql_timestamp(expires),
            remaining,
            sql_text("active"),
        ))

    validations = []
    trips = []
    validation_card = {}
    base_time = datetime(2026, 10, 16, 6, 0, tzinfo=MOSCOW_TZ)
    trip_id = 6001
    for offset, validation_id in enumerate(range(4001, 4501)):
        card_position = rng.randrange(len(card_ids))
        card_id = card_ids[card_position]
        card_product_id = product_record_ids[card_position]
        accepted = rng.random() < 0.92
        validated_at = base_time + timedelta(minutes=offset * 7)
        result = "accepted" if accepted else "rejected"
        amount = rng.choice([0, 55, 65, 70]) if accepted else 0
        validation_card[validation_id] = card_id
        validations.append((
            validation_id,
            card_id,
            rng.choice([1, 2, 3, 4]),
            card_product_id,
            "NULL",
            sql_text(result),
            f"{amount:.2f}",
            sql_timestamp(validated_at),
        ))
        if accepted:
            trips.append((
                trip_id,
                card_id,
                validation_id,
                sql_timestamp(validated_at),
                sql_timestamp(validated_at + timedelta(minutes=rng.randint(8, 55))),
            ))
            trip_id += 1

    operations = []
    deposits = []
    withdrawals = []
    accepted_validation_ids = [row[0] for row in validations if row[5] == sql_text("accepted")]
    for offset, operation_id in enumerate(range(5001, 5301)):
        card_id = rng.choice(card_ids)
        is_deposit = rng.random() < 0.55
        operation_type = "deposit" if is_deposit else "withdrawal"
        amount = rng.choice([50, 70, 100, 300, 500, 1000])
        operation_at = base_time + timedelta(minutes=offset * 11)
        operations.append((
            operation_id,
            card_id,
            sql_text(operation_type),
            f"{amount:.2f}",
            sql_timestamp(operation_at),
            sql_text("completed"),
        ))
        if is_deposit:
            deposits.append((operation_id, sql_text(rng.choice(["cash", "bank_card", "online"]))))
        else:
            matching = [vid for vid in accepted_validation_ids if validation_card[vid] == card_id]
            validation_id = rng.choice(matching) if matching else "NULL"
            withdrawals.append((operation_id, validation_id))

    with output_path.open("w", encoding="utf-8", newline="\n") as file:
        file.write("SET search_path TO transport_card;\n\nBEGIN;\n\n")
        write_insert(file, "e1_card_owner", ["owner_id", "passport_data", "full_name", "phone_number", "email"], owners, True)
        write_insert(file, "e2_card", ["card_id", "card_number", "owner_id", "issue_date", "validity_period_days", "current_balance", "status"], cards, True)
        write_insert(file, "e6_card_product", ["card_product_id", "card_id", "tariff_product_id", "activated_at", "expires_at", "remaining_trip_count", "status"], card_products, True)
        write_insert(file, "e9_validation", ["validation_id", "card_id", "validator_id", "card_product_id", "benefit_id", "result", "charged_amount", "validated_at"], validations, True)
        write_insert(file, "e10_trip", ["trip_id", "card_id", "validation_id", "started_at", "ended_at"], trips, True)
        write_insert(file, "e13_balance_operation", ["balance_operation_id", "card_id", "operation_type", "amount", "operation_at", "status"], operations, True)
        write_insert(file, "e17_balance_deposit", ["balance_operation_id", "payment_method"], deposits)
        write_insert(file, "e18_balance_withdrawal", ["balance_operation_id", "validation_id"], withdrawals)

        sequences = [
            ("e1_card_owner", "owner_id"),
            ("e2_card", "card_id"),
            ("e6_card_product", "card_product_id"),
            ("e9_validation", "validation_id"),
            ("e10_trip", "trip_id"),
            ("e13_balance_operation", "balance_operation_id"),
        ]
        for table, column in sequences:
            file.write(
                f"SELECT setval(pg_get_serial_sequence('{table}', '{column}'), "
                f"(SELECT max({column}) FROM {table}));\n"
            )
        file.write("\nCOMMIT;\n")


def main() -> None:
    default_output = Path(__file__).resolve().parents[1] / "generated" / "03_test_data.sql"
    parser = argparse.ArgumentParser(description="Генерация воспроизводимых тестовых данных для ЛР4")
    parser.add_argument("--output", type=Path, default=default_output)
    parser.add_argument("--seed", type=int, default=68)
    args = parser.parse_args()
    generate(args.output, args.seed)
    print(f"Создан файл: {args.output}")


if __name__ == "__main__":
    main()
