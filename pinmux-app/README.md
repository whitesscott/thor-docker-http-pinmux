 What was produced

  Database (schema.sql + seed.sql)

  Run once to bootstrap:
  psql -U <user> -d pinmux -f schema.sql
  psql -U <user> -d pinmux -f seed.sql
  Seeds 1,062 pin rows (269 configurable + 793 reference-only) and a ready-to-use Jetson Thor DevKit
  Template configuration.

  ---
  Backend (pinmux-app/backend/)

  src/
    index.js          Express app, port 3001
    db.js             pg connection pool
    validation.js     Port of Sheet26.cls (all 6 checks)
    dts.js            Port of Generate_Device_Tree.bas
    routes/
      pins.js         GET /api/pins, GET /api/pins/:id
      configurations.js  CRUD + per-pin update with live validation
      export.js       POST /api/configurations/:id/export/dts → ZIP
  cd pinmux-app/backend
  cp .env.example .env   # fill in DATABASE_URL
  npm install
  npm run dev

  Frontend (pinmux-app/frontend/)

  src/
    App.jsx              Top-level: config selector, loading, export
    api.js               All fetch calls
    components/
      ConfigToolbar.jsx  Config dropdown, New/Delete, board name, Export DTS
      PinmuxGrid.jsx     AG Grid with 40+ columns, pinned identity cols,
                         inline dropdowns, live validation cell colouring
  cd pinmux-app/frontend
  npm install
  npm run dev            # → http://localhost:5173

  ---
  Key behaviours replicated from the XLSM

  ┌──────────────────────────────────────────┬───────────────────────────────────────────────────────┐
  │          Spreadsheet behaviour           │                    Web equivalent                     │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Worksheet_Change validation on Customer  │ PUT /api/configurations/:id/pins/:pinId re-runs all 6 │
  │ Usage / Pin Direction / Wake / Resistor  │  checks server-side; flags written back to DB         │
  │ / RCV_SEL                                │                                                       │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Dropdown options vary per-pin            │ cellEditorParams is a function returning per-row      │
  │ (unused/GPIO/SFIO0-3)                    │ options                                               │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Red cells for INVALID                    │ is_valid = false → row-invalid CSS class; per-field   │
  │                                          │ valid_* → cell-invalid                                │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Generate_Device_Tree macro               │ POST /export/dts → streams a ZIP of 3 .dtsi files     │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Warning * suffix on function names       │ Preserved in errors/warnings response field           │
  ├──────────────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ Multiple configs / release variants      │ configurations table; seed-from-existing on create    │
  └──────────────────────────────────────────┴───────────────────────────────────────────────────────┘
