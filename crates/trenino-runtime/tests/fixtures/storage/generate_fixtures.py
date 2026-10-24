import argparse
import sqlite3
from pathlib import Path


def populate(database: Path, is_current: bool) -> None:
    connection = sqlite3.connect(database)
    connection.execute("PRAGMA foreign_keys=ON")
    timestamp = "2026-05-01T12:00:00Z"
    connection.execute(
        "INSERT INTO devices(id,name,inserted_at,updated_at,config_id,description) VALUES(7,'Desktop',?,?,42,'fixture device')",
        (timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO device_inputs(id,pin,input_type,sensitivity,device_id,inserted_at,updated_at,debounce,matrix_id,name) "
        "VALUES(17,0,'analog',3,7,?,?,NULL,NULL,'Throttle')",
        (timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO device_input_calibrations(id,max_hardware_value,min_value,max_value,has_rollover,is_inverted,input_id,inserted_at,updated_at) "
        "VALUES(27,1023,0,1023,0,0,17,?,?)",
        (timestamp, timestamp),
    )
    if is_current:
        connection.execute(
            "INSERT INTO trains(id,name,description,inserted_at,updated_at) VALUES(37,'Fixture train','preserve me',?,?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO train_identifiers(id,train_id,identifier,inserted_at,updated_at) VALUES(38,37,'RVM_FIXTURE',?,?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO device_i2c_modules(id,device_id,name,module_chip,i2c_address,inserted_at,updated_at,params) "
            "VALUES(57,7,'Cab display','ht16k33',112,?,?,?)",
            (
                timestamp,
                timestamp,
                '{"brightness":5,"num_digits":6,"display_type":"fourteen_segment",'
                '"has_dot":false,"align_right":true,"min_value":0.0}',
            ),
        )
    else:
        connection.execute(
            "INSERT INTO trains(id,name,description,identifier,inserted_at,updated_at) "
            "VALUES(37,'Fixture train','preserve me','  RVM_FIXTURE  ', ?,?)",
            (timestamp, timestamp),
        )

    connection.execute(
        "INSERT INTO train_elements(id,train_id,type,name,inserted_at,updated_at) VALUES(47,37,'lever','Throttle',?,?)",
        (timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO train_lever_configs(id,element_id,min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint,calibrated_at,inserted_at,updated_at,lever_type,inverted) "
        "VALUES(57,47,'/min','/max','/value',NULL,NULL,?,?,?,'analog',0)",
        (timestamp, timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO train_lever_notches(id,lever_config_id,'index',type,value,min_value,max_value,description,inserted_at,updated_at,input_min,input_max,sim_input_min,sim_input_max) "
        "VALUES(67,57,0,'linear',0.5,0.0,1.0,'Mid',?,?,0.0,1.0,0.0,1.0)",
        (timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO lever_input_bindings(id,lever_config_id,input_id,enabled,inserted_at,updated_at) VALUES(77,57,17,1,?,?)",
        (timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO scripts(id,train_id,name,enabled,code,triggers,inserted_at,updated_at) "
        "VALUES(87,37,'Automation',1,'return true','[\"manual\"]',?,?)",
        (timestamp, timestamp),
    )
    if is_current:
        connection.execute(
            "INSERT INTO train_display_bindings(id,train_id,i2c_module_id,name,endpoint,format_string,enabled,script_id,inserted_at,updated_at) "
            "VALUES(58,37,57,'Speed','/speed','{value}',1,87,?,?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO virtual_joystick_configurations(id,enabled,device_index,inserted_at,updated_at) VALUES(1,1,1,?,?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO virtual_joystick_mappings(id,input_id,device_index,target_type,axis,button,inverted,inserted_at,updated_at) "
            "VALUES(59,17,1,'axis','x',NULL,0,?,?)",
            (timestamp, timestamp),
        )
    connection.execute("INSERT INTO app_settings(key,value) VALUES('simulator_url','http://fixture.invalid')")
    connection.commit()
    with database.with_suffix(".sql").open("w", encoding="utf-8", newline="\n") as output:
        for statement in connection.iterdump():
            output.write(statement + ";\n")
    connection.close()


def export_schema(database: Path, destination: Path) -> None:
    connection = sqlite3.connect(database)
    rows = connection.execute(
        "SELECT sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' AND sql IS NOT NULL "
        "ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END,name"
    ).fetchall()
    destination.write_text(
        "\n\n".join(row[0] + ";" for row in rows) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    connection.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--v074-db", type=Path, required=True)
    parser.add_argument("--current-db", type=Path, required=True)
    parser.add_argument("--fixture-dir", type=Path, required=True)
    parser.add_argument("--schema-dir", type=Path, required=True)
    args = parser.parse_args()

    populate(args.v074_db, is_current=False)
    populate(args.current_db, is_current=True)
    export_schema(args.v074_db, args.schema_dir / "ecto-0.7.4.sql")
    export_schema(args.current_db, args.schema_dir / "ecto-current.sql")
    target = (args.schema_dir / "ecto-current.sql").read_text(encoding="utf-8")
    target = target.replace("CHECK (device_index = 1)", "CHECK (device_index BETWEEN 1 AND 16)")
    target += "\nCREATE TABLE rust_schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL);\n"
    (args.schema_dir / "rust-full-v2.sql").write_text(
        target, encoding="utf-8", newline="\n"
    )
    args.fixture_dir.mkdir(parents=True, exist_ok=True)
    print("Exported schemas and data from Ecto-migrated disposable databases.")


if __name__ == "__main__":
    main()
