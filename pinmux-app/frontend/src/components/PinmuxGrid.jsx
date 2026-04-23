import { useMemo, useCallback } from 'react';
import { AgGridReact } from 'ag-grid-react';
import { ModuleRegistry, AllCommunityModule } from 'ag-grid-community';
import 'ag-grid-community/styles/ag-grid.css';
import 'ag-grid-community/styles/ag-theme-alpine.css';

ModuleRegistry.registerModules([AllCommunityModule]);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function usageOptions(pin) {
  return [
    pin.mux_unused,
    pin.mux_gpio,
    pin.mux_sfio0,
    pin.mux_sfio1,
    pin.mux_sfio2,
    pin.mux_sfio3,
  ].filter(Boolean);
}

function directionOptions(pin, usage) {
  if (!usage) return [];
  if (usage.startsWith('unused_')) return ['Not Assigned'];

  const dirMap = {
    [pin.mux_gpio]: pin.allowed_dir_gpio,
    [pin.mux_sfio0]: pin.allowed_dir_sfio0,
    [pin.mux_sfio1]: pin.allowed_dir_sfio1,
    [pin.mux_sfio2]: pin.allowed_dir_sfio2,
    [pin.mux_sfio3]: pin.allowed_dir_sfio3,
  };

  const allowed = dirMap[usage];
  const base = ['Not Assigned'];

  if (!allowed || allowed === 'B') {
    base.push('Input', 'Output', 'Bidirectional', 'Open-Drain');
  } else if (allowed === 'I') {
    base.push('Input');
  } else if (allowed === 'O') {
    base.push('Output', 'Open-Drain');
  }

  return base;
}

const ENABLE_DISABLE  = ['', 'Enable', 'Disable'];
const WAKE_OPTS       = ['', 'Yes', 'No'];
const INITIAL_STATE   = ['', 'Z', 'Int PU', 'Int PD', 'Drive 0', 'Drive 1', 'N/A'];

// ---------------------------------------------------------------------------
// Column helpers
// ---------------------------------------------------------------------------

function selectEditor(valuesOrFn) {
  return {
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: (params) => ({
      values:
        typeof valuesOrFn === 'function'
          ? valuesOrFn(params.data, params)
          : valuesOrFn,
    }),
  };
}

// Cell class for an editable column.
// isSelect=true  -> orange + select styling hook
// isSelect=false -> plain orange
const editableField = (validKey, isSelect = false) => ({
  cellClass: (p) => {
    if (!p.data.is_configurable) return 'row-reference-only';
    if (validKey && p.data[`valid_${validKey}`] === false) return 'cell-invalid';
    return isSelect ? 'cell-editable-select' : 'cell-editable';
  },
});

// ---------------------------------------------------------------------------
// Column definitions
// ---------------------------------------------------------------------------

function buildColumns(onCellChanged) {
  const ro = { editable: false };
  const ref = { ...ro, cellClass: 'row-reference-only' };

  // Shorthand for editable customer columns.
  // applicable: optional fn(data) => bool — if false the cell is greyed out (not editable).
  const cust = (field, headerName, width, valuesOrFn, validKey, isSelect = false, applicable = null) => ({
    headerName,
    field,
    width,
    wrapHeaderText: true,
    editable: (p) => !!p.data.is_configurable && (!applicable || applicable(p.data)),
    ...(valuesOrFn ? selectEditor(valuesOrFn) : {}),
    cellClass: (p) => {
      if (!p.data.is_configurable) return 'row-reference-only';
      if (applicable && !applicable(p.data)) return 'row-reference-only';
      if (validKey && p.data[`valid_${validKey}`] === false) return 'cell-invalid';
      return isSelect ? 'cell-editable-select' : 'cell-editable';
    },
    onCellValueChanged: onCellChanged,
  });

  return [
    // ── XLSM Row # ─────────────────────────────────────────────────────────
    { headerName: 'Row', field: 'xlsm_row', width: 55, pinned: 'left', suppressAutoSize: true, ...ro },

    // ── Thor CVM Connector ─────────────────────────────────────────────────
    {
      headerName: 'Thor CVM Connector',
      headerClass: 'group-connector',
      children: [
        { headerName: 'Pin #', field: 'connector_pin', width: 125, pinned: 'left', suppressAutoSize: true, ...ro },
        { headerName: 'Signal Name', field: 'signal_name', width: 125, pinned: 'left', suppressAutoSize: true, ...ro },
      ],
    },

    // ── Package Ball Name ──────────────────────────────────────────────────
    {
      headerName: 'Package Ball Name',
      headerClass: 'group-ball',
      children: [
        { headerName: 'MPIO', field: 'ball_name', width: 120, pinned: 'left', suppressAutoSize: true, ...ro },
      ],
    },

    // ── Verilog Ball Name ──────────────────────────────────────────────────
    { headerName: 'Verilog Ball Name', field: 'verilog_name', width: 115, pinned: 'left', suppressAutoSize: true, ...ro },

    // ── Pad Info ───────────────────────────────────────────────────────────
    {
      headerName: 'Pad Info',
      headerClass: 'group-padinfo',
      children: [
        { headerName: 'Wake', field: 'wake_source', width: 80, ...ref },
        { headerName: 'Pad Category', field: 'pad_category', width: 90, ...ref },
        { headerName: 'Pull Strength', field: 'pull_strength', width: 90, ...ref },
        { headerName: 'Power Rail', field: 'power_rail', width: 100, ...ref },
      ],
    },

    // ── POR ────────────────────────────────────────────────────────────────
    {
      headerName: 'POR',
      children: [
        { headerName: 'Pin State', field: 'por_state', width: 80, ...ref },
      ],
    },

    // ── Filled in by Customers ─────────────────────────────────────────────
    {
      headerName: 'Filled in by Customers',
      headerClass: 'group-customer',
      children: [
        cust('customer_usage', 'Customer Usage', 200, (data) => usageOptions(data), 'customer_usage', true),
        cust('pin_direction', 'Pin Direction', 130, (data) => directionOptions(data, data.customer_usage), 'pin_direction', true),
        cust('initial_state', 'Req. Initial State', 120, INITIAL_STATE, 'initial_state', true),
        cust('wake_pin', 'Wake Pin', 85, WAKE_OPTS, 'wake', true, (data) => !!data.wake_source),
        {
          headerName: 'E_IO_OD\nOpen-Drain Select',
          field: 'e_io_od',
          width: 95,
          wrapHeaderText: true,
          editable: (p) => !!p.data.is_configurable,
          ...selectEditor(ENABLE_DISABLE),
          ...editableField('rcv_sel', true),
          onCellValueChanged: onCellChanged,
        },
        cust('drv_type', 'DRV_TYPE\nDisable=Normal\nEnable=High', 95, ENABLE_DISABLE, null, true, (data) => !!data.drv_type_applicable),
        { headerName: 'Int Pull Up Value (Ω)',   field: 'int_pull_up',   wrapHeaderText: true, width: 110, ...ref },
        { headerName: 'Int Pull Down Value (Ω)', field: 'int_pull_down', wrapHeaderText: true, width: 110, ...ref },
        cust('ext_pull_up', 'Ext Pull Up Value (Ω)', 110, null, 'resistor'),
        cust('ext_pull_down', 'Ext Pull Down Value (Ω)', 110, null, null),
        cust('deep_sleep_state', 'Req. Deep Sleep State', 120, null, null),
        { headerName: 'IO Block Voltage', field: 'io_block_voltage', width: 95, ...ref },
      ],
    },

    // ── Info ───────────────────────────────────────────────────────────────
    { headerName: 'DT Pin Name', field: 'dt_pin_name', width: 170, hide: true, ...ref },
    cust('net_name', 'Customer Usage Description\nor Net Names', 180, null, null),
    {
      headerName: 'Devkit Usage', field: 'devkit_usage', width: 160, ...ro,
      cellClass: (p) => {
        const v = p.value;
        if (v === 'UNUSED') return 'devkit-unused';
        if (v === 'STRAP')  return 'devkit-strap';
        if (v)              return 'devkit-value';
        return 'row-reference-only';
      },
    },
    { ...cust('ball_location', 'Ball Loc.', 70, null, null), hide: true },
    { headerName: 'Comment', field: 'comment', width: 200, ...ref },
  ];
}

// ---------------------------------------------------------------------------
// Row styling
// ---------------------------------------------------------------------------

function getRowClass(params) {
  if (!params.data.is_configurable) return 'row-section-divider';
  if (params.data.is_valid === false) return 'row-invalid';
  return 'row-configurable';
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function PinmuxGrid({ rows, configId, onRowsUpdated }) {
  const visibleRows = useMemo(
    () => rows.filter((r) => r.xlsm_row != null),
    [rows]
  );

  const handleCellChanged = useCallback(
    async (event) => {
      const { data, colDef, newValue, oldValue, node, api } = event;
      if (!data?.is_configurable || !configId) return;

      const field = colDef.field;
      if (!field) return;

      // Skip no-op edits.
      if ((newValue ?? '') === (oldValue ?? '')) return;

      try {
        const { api: backendApi } = await import('../api.js');
        const result = await backendApi.updatePin(configId, data.pin_id, {
          [field]: newValue ?? '',
        });

        // Merge server response back into the row so validation flags refresh.
        const merged = { ...data, ...result };
        api.applyTransaction({ update: [merged] });
        onRowsUpdated?.();
      } catch (err) {
        console.error('Save failed:', err);

        // Restore the old value on failure.
        node.setDataValue(field, oldValue ?? '');

        if (typeof window !== 'undefined' && window.alert) {
          window.alert(`Save failed: ${err.message}`);
        }
      }
    },
    [configId, onRowsUpdated]
  );

  const columnDefs = useMemo(
    () => buildColumns(handleCellChanged),
    [handleCellChanged]
  );

  const defaultColDef = useMemo(
    () => ({
      resizable: true,
      sortable: true,
      filter: true,
      suppressMovable: false,
      autoHeaderHeight: true,
    }),
    []
  );

  return (
    <div className="grid-wrap ag-theme-alpine">
      <AgGridReact
        theme="legacy"
        rowData={visibleRows}
        columnDefs={columnDefs}
        defaultColDef={defaultColDef}
        getRowId={(p) => String(p.data.sort_order)}
        getRowClass={getRowClass}
        singleClickEdit={true}
        suppressRowClickSelection={true}
        stopEditingWhenCellsLoseFocus={true}
        enableCellTextSelection={true}
        tooltipShowDelay={300}
        rowBuffer={20}
        onFirstDataRendered={(p) => p.api.autoSizeAllColumns()}
      />
    </div>
  );
}

export default PinmuxGrid;

