#!/usr/bin/env python3
"""
extract_xlsm.py
---------------
Parses Jetson_Thor_Series_Modules_Pinmux_Template.xlsm and produces:
  - schema.sql   : PostgreSQL DDL for all tables
  - seed.sql     : INSERT statements for reference data and the DevKit template

Uses only Python stdlib (zipfile + xml.etree.ElementTree).

Usage:
  python3 extract_xlsm.py [path/to/Jetson_Thor_Series_Modules_Pinmux_Template.xlsm]

Defaults to ./original_xlsm/Jetson_Thor_Series_Modules_Pinmux_Template.xlsm
"""

import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

XLSM_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else \
    Path(__file__).parent / "original_xlsm" / "Jetson_Thor_Series_Modules_Pinmux_Template_v1.7.xlsm"

OUTPUT_DIR = Path(__file__).parent

NS = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

# Row numbers (1-based, matching Excel) for the main pin table and pad voltage
FIRST_PIN_ROW   = 10
LAST_PIN_ROW    = 1103   # includes all sections through FSI oscillator pins
CONFIG_FIRST_ROW = 10    # configurable range per named range ConfigFirstCell
CONFIG_LAST_ROW  = 291   # row 292 = "Dedicated SFIOs" section header, not a pin

# Pad voltage table is in columns BK/BL, rows 1109-1111 (per named ranges)
PAD_VOLTAGE_FIRST = 1109
PAD_VOLTAGE_LAST  = 1111

# ---------------------------------------------------------------------------
# Column letter helpers
# ---------------------------------------------------------------------------

def col_letter_to_index(col: str) -> int:
    """Convert Excel column letter(s) to 0-based index. 'A'→0, 'Z'→25, 'AA'→26."""
    col = col.upper()
    result = 0
    for ch in col:
        result = result * 26 + (ord(ch) - ord('A') + 1)
    return result - 1


# Column letter → field-name mapping for the pins table
# (checker columns AL-AR are intentionally omitted from the DB)
PIN_COLUMNS = {
    "A":  "connector_pin",
    "B":  "signal_name",
    "C":  "ball_name",
    "D":  "verilog_name",
    "E":  "mux_unused",
    "F":  "mux_gpio",
    "G":  "mux_sfio0",
    "H":  "mux_sfio1",
    "I":  "mux_sfio2",
    "J":  "mux_sfio3",
    "K":  "allowed_dir_gpio",
    "L":  "allowed_dir_sfio0",
    "M":  "allowed_dir_sfio1",
    "N":  "allowed_dir_sfio2",
    "O":  "allowed_dir_sfio3",
    "P":  "func_f0",
    "Q":  "func_f1",
    "R":  "func_f2",
    "S":  "func_f3",
    "T":  "func_safe",
    "U":  "dt_pin_name",
    "V":  "power_rail",
    "W":  "wake_source",
    "X":  "strap",
    "Y":  "gte",
    "Z":  "dpd_control",
    "AA": "dpd_group",
    "AB": "pad_category",
    "AC": "pad_type",
    "AD": "pull_strength",
    "AE": "por_state",
    "AF": "default_pin_group",
    "AG": "sdmmc_dat_cmd",
    "AH": "default_pupd",
    "AI": "default_tristate",
    "AJ": "default_e_input",
    "AK": "default_gpio_init",
    # Template defaults (DevKit values from "Filled in by Customers" section)
    "AS": "tmpl_customer_usage",
    "AT": "tmpl_pin_direction",
    "AU": "tmpl_initial_state",
    "AV": "tmpl_wake_pin",
    "AW": "tmpl_lock",
    "AX": "tmpl_e_io_od",
    "AY": "tmpl_drv_type",
    "AZ": "tmpl_e_lpbk",
    "BA": "tmpl_e_18v",
    "BB": "tmpl_schmitt",
    "BC": "tmpl_e_hsrx18v",
    "BD": "tmpl_int_pull_up",
    "BE": "tmpl_int_pull_down",
    "BF": "tmpl_ext_pull_up",
    "BG": "tmpl_ext_pull_down",
    "BH": "tmpl_deep_sleep_state",
    "BI": "io_block_voltage",
    "BJ": "net_name",
    "BK": "devkit_usage",
    "BL": "ball_location",
    "BM": "gpio_true_direction",
    "BN": "comment",
}

# Pre-build index→fieldname map once
INDEX_TO_FIELD = {col_letter_to_index(col): field for col, field in PIN_COLUMNS.items()}

# Pad voltage columns (within the pad voltage section, BK=rail, BL=setting)
PAD_V_RAIL_COL    = col_letter_to_index("BK")
PAD_V_SETTING_COL = col_letter_to_index("BL")

# ---------------------------------------------------------------------------
# XLSM parsing
# ---------------------------------------------------------------------------

def load_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    with zf.open("xl/sharedStrings.xml") as f:
        root = ET.parse(f).getroot()
    strings = []
    for si in root.findall("x:si", NS):
        text = "".join(t.text or "" for t in si.findall(".//x:t", NS))
        strings.append(text)
    return strings


def get_cell_value(cell: ET.Element, shared_strings: list[str]) -> str:
    t = cell.get("t", "")
    v_el = cell.find("x:v", NS)
    if v_el is None:
        return ""
    v = v_el.text or ""
    if t == "s":
        return shared_strings[int(v)]
    if t == "b":
        return "TRUE" if v == "1" else "FALSE"
    return v


def parse_sheet(zf: zipfile.ZipFile, sheet_path: str,
                shared_strings: list[str]) -> tuple[dict[int, dict[int, str]], set[int]]:
    """Return ({row_number: {col_index: value}}, {hidden_row_numbers}) for all non-empty cells."""
    with zf.open(sheet_path) as f:
        root = ET.parse(f).getroot()

    result: dict[int, dict[int, str]] = {}
    hidden_rows: set[int] = set()
    for row_el in root.findall(".//x:sheetData/x:row", NS):
        row_num = int(row_el.get("r", 0))
        if row_el.get("hidden") == "1":
            hidden_rows.add(row_num)
        row_data: dict[int, str] = {}
        for cell in row_el:
            cell_ref = cell.get("r", "")
            col_str = "".join(c for c in cell_ref if c.isalpha())
            col_idx = col_letter_to_index(col_str)
            val = get_cell_value(cell, shared_strings)
            if val not in ("", "FALSE"):      # skip empty / boolean-false checker cells
                row_data[col_idx] = val
        if row_data:
            result[row_num] = row_data
    return result, hidden_rows


def extract_pins(rows: dict[int, dict[int, str]], hidden_rows: set[int]) -> list[dict]:
    """
    Extract pin rows.  A row is a pin if column E (mux_unused) starts with
    'unused_', which is definitive for every configurable MPIO.
    """
    e_idx = col_letter_to_index("E")
    pins = []
    sort_order = 0
    for row_num in sorted(rows.keys()):
        if row_num < FIRST_PIN_ROW or row_num > LAST_PIN_ROW:
            continue
        row = rows[row_num]
        unused_val = row.get(e_idx, "")
        if not unused_val.lower().startswith("unused_"):
            continue

        sort_order += 1
        pin: dict = {
            "row_number":       row_num,
            "is_configurable":  CONFIG_FIRST_ROW <= row_num <= CONFIG_LAST_ROW,
            "is_hidden":        row_num in hidden_rows,
            "sort_order":       sort_order,
        }
        for col_idx, field in INDEX_TO_FIELD.items():
            pin[field] = row.get(col_idx, "")
        pins.append(pin)
    return pins


def extract_pad_voltages(rows: dict[int, dict[int, str]]) -> list[dict]:
    """Extract the pad voltage table (rows 1109-1111, cols BK/BL)."""
    entries = []
    for row_num in range(PAD_VOLTAGE_FIRST, PAD_VOLTAGE_LAST + 1):
        row = rows.get(row_num, {})
        rail    = row.get(PAD_V_RAIL_COL, "")
        setting = row.get(PAD_V_SETTING_COL, "")
        if rail and rail not in ("Voltage Rail",):
            entries.append({"voltage_rail": rail, "voltage_setting": setting})
    return entries


# ---------------------------------------------------------------------------
# SQL helpers
# ---------------------------------------------------------------------------

def sq(val) -> str:
    """Escape a value as a SQL string literal, or NULL."""
    if val is None or val == "":
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    escaped = str(val).replace("'", "''")
    return f"'{escaped}'"


def sb(val: bool) -> str:
    return "TRUE" if val else "FALSE"


# ---------------------------------------------------------------------------
# Schema DDL
# ---------------------------------------------------------------------------

SCHEMA_SQL = """\
-- =============================================================================
-- Jetson Thor Pinmux – PostgreSQL Schema
-- Generated by extract_xlsm.py
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- pins
--   Static reference data for every MPIO pad on the Thor SoC.
--   Populated once from the XLSM template; never modified at runtime.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pins (
    id                   SERIAL PRIMARY KEY,
    row_number           INTEGER      NOT NULL,  -- original Excel row (debugging)
    sort_order           INTEGER      NOT NULL,

    -- Physical identity
    connector_pin        VARCHAR(20),             -- e.g. "L60"  (module connector ball)
    signal_name          VARCHAR(100),            -- e.g. "SYS_RESET_N"
    ball_name            VARCHAR(50)  NOT NULL,   -- MPIO name, e.g. "SF_RST_N"
    verilog_name         VARCHAR(100),            -- Verilog signal name
    ball_location        VARCHAR(20),             -- physical SoC ball, e.g. "K55"

    -- Mux options (dropdown choices for customer_usage)
    mux_unused           VARCHAR(100),
    mux_gpio             VARCHAR(100),
    mux_sfio0            VARCHAR(100),
    mux_sfio1            VARCHAR(100),
    mux_sfio2            VARCHAR(100),
    mux_sfio3            VARCHAR(100),

    -- Allowed pin directions per mux option  (I=Input, O=Output, B=Bidirectional)
    allowed_dir_gpio     VARCHAR(5),
    allowed_dir_sfio0    VARCHAR(5),
    allowed_dir_sfio1    VARCHAR(5),
    allowed_dir_sfio2    VARCHAR(5),
    allowed_dir_sfio3    VARCHAR(5),

    -- Pin group functions
    func_f0              VARCHAR(100),
    func_f1              VARCHAR(100),
    func_f2              VARCHAR(100),
    func_f3              VARCHAR(100),
    func_safe            VARCHAR(100),

    -- General pad information
    dt_pin_name          VARCHAR(100),            -- Linux device-tree pin name
    power_rail           VARCHAR(100),
    wake_source          VARCHAR(50),             -- e.g. "wake0"
    strap                VARCHAR(50),
    gte                  VARCHAR(100),
    dpd_control          VARCHAR(100),
    dpd_group            VARCHAR(100),
    pad_category         VARCHAR(50),
    pad_type             VARCHAR(200),
    pull_strength        VARCHAR(20),
    por_state            VARCHAR(20),             -- Power-On Reset state
    io_block_voltage     VARCHAR(20),
    sdmmc_dat_cmd        VARCHAR(50),
    net_name             VARCHAR(200),
    devkit_usage         VARCHAR(200),
    gpio_true_direction  VARCHAR(20),
    comment              TEXT,

    -- Power-On Reset / hardware default configuration
    default_pin_group    VARCHAR(100),
    default_pupd         VARCHAR(20),             -- NORMAL / PULL_UP / PULL_DOWN
    default_tristate     VARCHAR(20),             -- NORMAL / TRISTATE
    default_e_input      VARCHAR(20),             -- ENABLE / DISABLE
    default_gpio_init    VARCHAR(10),             -- N/A / 0 / 1

    -- DevKit template defaults (pre-filled "Filled in by Customers" values)
    -- These seed new configurations so users start from the DevKit baseline.
    tmpl_customer_usage  VARCHAR(100),
    tmpl_pin_direction   VARCHAR(30),
    tmpl_initial_state   VARCHAR(30),
    tmpl_wake_pin        VARCHAR(10),
    tmpl_lock            VARCHAR(10),
    tmpl_e_io_od         VARCHAR(10),
    tmpl_drv_type        VARCHAR(10),
    tmpl_e_lpbk          VARCHAR(10),
    tmpl_e_18v           VARCHAR(10),
    tmpl_schmitt         VARCHAR(20),
    tmpl_e_hsrx18v       VARCHAR(10),
    tmpl_int_pull_up     VARCHAR(20),
    tmpl_int_pull_down   VARCHAR(20),
    tmpl_ext_pull_up     VARCHAR(20),
    tmpl_ext_pull_down   VARCHAR(20),
    tmpl_deep_sleep_state VARCHAR(30),

    -- Whether this pin can be reconfigured by a customer
    -- (FALSE for oscillator/special-function pads outside the config range)
    is_configurable      BOOLEAN      NOT NULL DEFAULT TRUE,

    -- Whether this pin row is hidden by default in the spreadsheet view
    -- (TRUE = hidden in v1.7 "Jetson Thor_DevKit" sheet; shown only when user toggles)
    is_hidden            BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS pins_ball_name_idx ON pins(ball_name);
CREATE INDEX        IF NOT EXISTS pins_sort_order_idx ON pins(sort_order);

-- ---------------------------------------------------------------------------
-- pad_voltage_rails
--   Reference list of pad voltage rails and their supported voltages.
--   The DevKit default voltage is stored here; per-configuration overrides
--   live in pad_voltage_configs.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pad_voltage_rails (
    id              SERIAL PRIMARY KEY,
    voltage_rail    VARCHAR(50)  NOT NULL UNIQUE,
    default_setting VARCHAR(30)  NOT NULL         -- e.g. "3.3V", "1.8V", "1.8V/3.3V"
);

-- ---------------------------------------------------------------------------
-- configurations
--   One row per user pinmux project.  Multiple configurations can coexist
--   (e.g. different board variants).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS configurations (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    board_name   VARCHAR(100),
    revision     INTEGER      NOT NULL DEFAULT 1,
    notes        TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- pin_configs
--   Per-pin customer choices within a configuration.
--   Seeded from the tmpl_* fields in pins; updated by the user via the UI.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pin_configs (
    id               SERIAL PRIMARY KEY,
    config_id        INTEGER      NOT NULL REFERENCES configurations(id) ON DELETE CASCADE,
    pin_id           INTEGER      NOT NULL REFERENCES pins(id)           ON DELETE RESTRICT,

    -- Customer choices (mirrors the "Filled in by Customers" columns AS–BH)
    customer_usage   VARCHAR(100),
    pin_direction    VARCHAR(30),
    initial_state    VARCHAR(30),
    wake_pin         VARCHAR(10),
    lock             VARCHAR(10),
    e_io_od          VARCHAR(10),    -- E_IO_OD / Open-Drain Select
    drv_type         VARCHAR(10),    -- DRV_TYPE (LPDR)
    e_lpbk           VARCHAR(10),    -- E_LPBK Loopback Select
    e_18v            VARCHAR(10),    -- E_18V
    schmitt          VARCHAR(20),
    e_hsrx18v        VARCHAR(10),
    int_pull_up      VARCHAR(20),    -- internal pull-up resistor value
    int_pull_down    VARCHAR(20),
    ext_pull_up      VARCHAR(20),    -- external pull-up resistor value
    ext_pull_down    VARCHAR(20),
    deep_sleep_state VARCHAR(30),

    -- Pin electrical config (cols AH-AK; customer-editable, used by DTS generator)
    pupd             VARCHAR(20),    -- NORMAL / PULL_UP / PULL_DOWN
    tristate         VARCHAR(20),    -- NORMAL / TRISTATE
    e_input          VARCHAR(20),    -- ENABLE / DISABLE
    gpio_init        VARCHAR(10),    -- N/A / 0 / 1

    -- Computed validation results (updated server-side on every save)
    valid_customer_usage   BOOLEAN,
    valid_pin_direction    BOOLEAN,
    valid_initial_state    BOOLEAN,
    valid_wake             BOOLEAN,
    valid_resistor         BOOLEAN,
    valid_rcv_sel          BOOLEAN,
    is_valid               BOOLEAN  GENERATED ALWAYS AS (
        COALESCE(valid_customer_usage, TRUE)
        AND COALESCE(valid_pin_direction, TRUE)
        AND COALESCE(valid_initial_state, TRUE)
        AND COALESCE(valid_wake, TRUE)
        AND COALESCE(valid_resistor, TRUE)
        AND COALESCE(valid_rcv_sel, TRUE)
    ) STORED,

    UNIQUE (config_id, pin_id)
);

CREATE INDEX IF NOT EXISTS pin_configs_config_idx ON pin_configs(config_id);

-- ---------------------------------------------------------------------------
-- pad_voltage_configs
--   Per-configuration voltage rail overrides.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pad_voltage_configs (
    id              SERIAL PRIMARY KEY,
    config_id       INTEGER      NOT NULL REFERENCES configurations(id) ON DELETE CASCADE,
    rail_id         INTEGER      NOT NULL REFERENCES pad_voltage_rails(id) ON DELETE RESTRICT,
    voltage_setting VARCHAR(30)  NOT NULL,
    UNIQUE (config_id, rail_id)
);

COMMIT;
"""

# ---------------------------------------------------------------------------
# Seed data builder
# ---------------------------------------------------------------------------

def build_seed_sql(pins: list[dict], pad_voltages: list[dict]) -> str:
    lines: list[str] = []
    lines.append("-- =============================================================================")
    lines.append("-- Jetson Thor Pinmux – Seed Data")
    lines.append(f"-- Generated by extract_xlsm.py from {XLSM_PATH.name}")
    lines.append(f"-- Total pins: {len(pins)}")
    lines.append("-- =============================================================================")
    lines.append("")
    lines.append("BEGIN;")
    lines.append("")

    # ---- pins ---------------------------------------------------------------
    lines.append("-- ---------------------------------------------------------------------------")
    lines.append("-- pins  (reference data)")
    lines.append("-- ---------------------------------------------------------------------------")
    lines.append("INSERT INTO pins (")
    lines.append("    row_number, sort_order, is_configurable, is_hidden,")
    lines.append("    connector_pin, signal_name, ball_name, verilog_name, ball_location,")
    lines.append("    mux_unused, mux_gpio, mux_sfio0, mux_sfio1, mux_sfio2, mux_sfio3,")
    lines.append("    allowed_dir_gpio, allowed_dir_sfio0, allowed_dir_sfio1,")
    lines.append("    allowed_dir_sfio2, allowed_dir_sfio3,")
    lines.append("    func_f0, func_f1, func_f2, func_f3, func_safe,")
    lines.append("    dt_pin_name, power_rail, wake_source, strap, gte,")
    lines.append("    dpd_control, dpd_group, pad_category, pad_type,")
    lines.append("    pull_strength, por_state, io_block_voltage,")
    lines.append("    sdmmc_dat_cmd, net_name, devkit_usage, gpio_true_direction, comment,")
    lines.append("    default_pin_group, default_pupd, default_tristate,")
    lines.append("    default_e_input, default_gpio_init,")
    lines.append("    tmpl_customer_usage, tmpl_pin_direction, tmpl_initial_state,")
    lines.append("    tmpl_wake_pin, tmpl_lock, tmpl_e_io_od, tmpl_drv_type, tmpl_e_lpbk,")
    lines.append("    tmpl_e_18v, tmpl_schmitt, tmpl_e_hsrx18v,")
    lines.append("    tmpl_int_pull_up, tmpl_int_pull_down,")
    lines.append("    tmpl_ext_pull_up, tmpl_ext_pull_down, tmpl_deep_sleep_state")
    lines.append(") VALUES")

    def p(pin, field):
        return sq(pin.get(field, ""))

    rows_sql = []
    for pin in pins:
        rows_sql.append(
            f"    ({pin['row_number']}, {pin['sort_order']}, {sb(pin['is_configurable'])}, {sb(pin['is_hidden'])},\n"
            f"     {p(pin,'connector_pin')}, {p(pin,'signal_name')}, {p(pin,'ball_name')}, "
            f"{p(pin,'verilog_name')}, {p(pin,'ball_location')},\n"
            f"     {p(pin,'mux_unused')}, {p(pin,'mux_gpio')}, {p(pin,'mux_sfio0')}, "
            f"{p(pin,'mux_sfio1')}, {p(pin,'mux_sfio2')}, {p(pin,'mux_sfio3')},\n"
            f"     {p(pin,'allowed_dir_gpio')}, {p(pin,'allowed_dir_sfio0')}, {p(pin,'allowed_dir_sfio1')},\n"
            f"     {p(pin,'allowed_dir_sfio2')}, {p(pin,'allowed_dir_sfio3')},\n"
            f"     {p(pin,'func_f0')}, {p(pin,'func_f1')}, {p(pin,'func_f2')}, "
            f"{p(pin,'func_f3')}, {p(pin,'func_safe')},\n"
            f"     {p(pin,'dt_pin_name')}, {p(pin,'power_rail')}, {p(pin,'wake_source')}, "
            f"{p(pin,'strap')}, {p(pin,'gte')},\n"
            f"     {p(pin,'dpd_control')}, {p(pin,'dpd_group')}, {p(pin,'pad_category')}, "
            f"{p(pin,'pad_type')},\n"
            f"     {p(pin,'pull_strength')}, {p(pin,'por_state')}, {p(pin,'io_block_voltage')},\n"
            f"     {p(pin,'sdmmc_dat_cmd')}, {p(pin,'net_name')}, {p(pin,'devkit_usage')}, "
            f"{p(pin,'gpio_true_direction')}, {p(pin,'comment')},\n"
            f"     {p(pin,'default_pin_group')}, {p(pin,'default_pupd')}, {p(pin,'default_tristate')},\n"
            f"     {p(pin,'default_e_input')}, {p(pin,'default_gpio_init')},\n"
            f"     {p(pin,'tmpl_customer_usage')}, {p(pin,'tmpl_pin_direction')}, "
            f"{p(pin,'tmpl_initial_state')},\n"
            f"     {p(pin,'tmpl_wake_pin')}, {p(pin,'tmpl_lock')}, {p(pin,'tmpl_e_io_od')}, "
            f"{p(pin,'tmpl_drv_type')}, {p(pin,'tmpl_e_lpbk')},\n"
            f"     {p(pin,'tmpl_e_18v')}, {p(pin,'tmpl_schmitt')}, {p(pin,'tmpl_e_hsrx18v')},\n"
            f"     {p(pin,'tmpl_int_pull_up')}, {p(pin,'tmpl_int_pull_down')},\n"
            f"     {p(pin,'tmpl_ext_pull_up')}, {p(pin,'tmpl_ext_pull_down')}, "
            f"{p(pin,'tmpl_deep_sleep_state')})"
        )

    lines.append(",\n".join(rows_sql) + ";")
    lines.append("")

    # ---- pad_voltage_rails --------------------------------------------------
    lines.append("-- ---------------------------------------------------------------------------")
    lines.append("-- pad_voltage_rails  (reference defaults)")
    lines.append("-- ---------------------------------------------------------------------------")
    if pad_voltages:
        lines.append("INSERT INTO pad_voltage_rails (voltage_rail, default_setting) VALUES")
        pv_rows = [f"    ({sq(pv['voltage_rail'])}, {sq(pv['voltage_setting'])})"
                   for pv in pad_voltages]
        lines.append(",\n".join(pv_rows) + ";")
    else:
        lines.append("-- (no pad voltage entries found in expected range)")
    lines.append("")

    # ---- seed a DevKit template configuration -------------------------------
    lines.append("-- ---------------------------------------------------------------------------")
    lines.append("-- Seed a 'DevKit Template' configuration pre-filled from the XLSM defaults")
    lines.append("-- ---------------------------------------------------------------------------")
    lines.append("INSERT INTO configurations (name, board_name, revision, notes)")
    lines.append("VALUES ('Jetson Thor DevKit Template',")
    lines.append("        'jetson-thor-devkit', 39,")
    lines.append("        'Auto-seeded from Jetson_Thor_Series_Modules_Pinmux_Template.xlsm rev 39');")
    lines.append("")
    lines.append("-- pin_configs for the DevKit template (config_id = 1)")
    lines.append("INSERT INTO pin_configs (")
    lines.append("    config_id, pin_id,")
    lines.append("    pupd, tristate, e_input, gpio_init,")
    lines.append("    customer_usage, pin_direction, initial_state,")
    lines.append("    wake_pin, lock, e_io_od, drv_type, e_lpbk,")
    lines.append("    e_18v, schmitt, e_hsrx18v,")
    lines.append("    int_pull_up, int_pull_down, ext_pull_up, ext_pull_down, deep_sleep_state")
    lines.append(")")
    lines.append("SELECT")
    lines.append("    1, p.id,")
    lines.append("    p.default_pupd, p.default_tristate, p.default_e_input, p.default_gpio_init,")
    lines.append("    p.tmpl_customer_usage, p.tmpl_pin_direction, p.tmpl_initial_state,")
    lines.append("    p.tmpl_wake_pin, p.tmpl_lock, p.tmpl_e_io_od, p.tmpl_drv_type, p.tmpl_e_lpbk,")
    lines.append("    p.tmpl_e_18v, p.tmpl_schmitt, p.tmpl_e_hsrx18v,")
    lines.append("    p.tmpl_int_pull_up, p.tmpl_int_pull_down,")
    lines.append("    p.tmpl_ext_pull_up, p.tmpl_ext_pull_down, p.tmpl_deep_sleep_state")
    lines.append("FROM pins p")
    lines.append("WHERE p.is_configurable = TRUE")
    lines.append("ORDER BY p.sort_order;")
    lines.append("")
    lines.append("-- pad_voltage_configs for the DevKit template")
    lines.append("INSERT INTO pad_voltage_configs (config_id, rail_id, voltage_setting)")
    lines.append("SELECT 1, pvr.id, pvr.default_setting")
    lines.append("FROM pad_voltage_rails pvr;")
    lines.append("")
    lines.append("COMMIT;")

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if not XLSM_PATH.exists():
        print(f"ERROR: Cannot find XLSM at {XLSM_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Opening {XLSM_PATH} …")
    with zipfile.ZipFile(XLSM_PATH) as zf:
        print("  Loading shared strings …")
        shared_strings = load_shared_strings(zf)
        print(f"  {len(shared_strings)} shared strings loaded.")

        print("  Parsing sheet3 (Jetson Thor_DevKit) …")
        rows, hidden_rows = parse_sheet(zf, "xl/worksheets/sheet3.xml", shared_strings)
        print(f"  {len(rows)} non-empty rows found, {len(hidden_rows)} hidden rows.")

    pins = extract_pins(rows, hidden_rows)
    configurable = sum(1 for p in pins if p["is_configurable"])
    hidden_pins  = sum(1 for p in pins if p["is_hidden"])
    print(f"  {len(pins)} pin rows extracted ({configurable} configurable, "
          f"{len(pins)-configurable} reference-only, {hidden_pins} hidden).")

    pad_voltages = extract_pad_voltages(rows)
    print(f"  {len(pad_voltages)} pad voltage rail entries extracted.")

    schema_path = OUTPUT_DIR / "schema.sql"
    seed_path   = OUTPUT_DIR / "seed.sql"

    print(f"\nWriting {schema_path} …")
    schema_path.write_text(SCHEMA_SQL, encoding="utf-8")

    print(f"Writing {seed_path} …")
    seed_sql = build_seed_sql(pins, pad_voltages)
    seed_path.write_text(seed_sql, encoding="utf-8")

    print("\nDone.")
    print(f"  {schema_path}  ({schema_path.stat().st_size:,} bytes)")
    print(f"  {seed_path}    ({seed_path.stat().st_size:,} bytes)")
    print("\nTo load into PostgreSQL:")
    print("  psql -U <user> -d <db> -f schema.sql")
    print("  psql -U <user> -d <db> -f seed.sql")


if __name__ == "__main__":
    main()
