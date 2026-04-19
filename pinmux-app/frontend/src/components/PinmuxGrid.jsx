import { useMemo, useCallback, useRef, forwardRef, useImperativeHandle, useState } from 'react';
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
    pin.mux_unused, pin.mux_gpio,
    pin.mux_sfio0, pin.mux_sfio1, pin.mux_sfio2, pin.mux_sfio3,
  ].filter(Boolean);
}

function directionOptions(pin, usage) {
  if (!usage) return [];
  if (usage.startsWith('unused_')) return ['Not Assigned'];
  const dirMap = {
    [pin.mux_gpio]:   pin.allowed_dir_gpio,
    [pin.mux_sfio0]:  pin.allowed_dir_sfio0,
    [pin.mux_sfio1]:  pin.allowed_dir_sfio1,
    [pin.mux_sfio2]:  pin.allowed_dir_sfio2,
    [pin.mux_sfio3]:  pin.allowed_dir_sfio3,
  };
  const allowed = dirMap[usage];
  const base = ['Not Assigned'];
  if (!allowed || allowed === 'B') base.push('Input', 'Output', 'Bidirectional', 'Open-Drain');
  else if (allowed === 'I') base.push('Input');
  else if (allowed === 'O') base.push('Output', 'Open-Drain');
  return base;
}

// Standard enum options
const ENABLE_DISABLE = ['', 'Enable', 'Disable'];
const WAKE_OPTS      = ['', 'Yes', 'No'];

// ---------------------------------------------------------------------------
// Custom dropdown cell editor — renders the option list immediately.
//
// isPopup: false keeps the editor inline (prevents stopEditingWhenCellsLoseFocus
// from cancelling the edit when the user clicks a list option).
// The list itself uses position:fixed anchored to eGridCell.getBoundingClientRect()
// so it visually drops below the cell without being clipped by overflow:hidden.
// ---------------------------------------------------------------------------
const DropdownCellEditor = forwardRef(({ value, values = [], stopEditing, eGridCell }, ref) => {
  // Ref-based committed value so getValue() is always synchronously current
  // even before React flushes the setCurrent state update.
  const committedRef = useRef(value ?? '');
  const [current, setCurrent] = useState(value ?? '');

  useImperativeHandle(ref, () => ({
    getValue: () => committedRef.current,
    isPopup:  () => false,
  }));

  // Position the list directly below the cell in viewport coordinates.
  const r = eGridCell?.getBoundingClientRect();

  function pick(v) {
    committedRef.current = v;
    setCurrent(v);
    stopEditing();
  }

  return (
    <div style={{ width: '100%', height: '100%' }}>
      <div
        className="dd-editor"
        style={{
          position: 'fixed',
          top:      r ? r.bottom  : 0,
          left:     r ? r.left    : 0,
          minWidth: r ? r.width   : 160,
        }}
      >
        {values.map((v) => (
          <div
            key={v ?? '__empty__'}
            className={`dd-option${v === current ? ' dd-selected' : ''}`}
            onMouseDown={(e) => {
              e.preventDefault();
              e.stopPropagation();
              pick(v);
            }}
          >
            {v || <span className="dd-empty">(none)</span>}
          </div>
        ))}
      </div>
    </div>
  );
});

// Helper: dropdown column extra props
const dropdownEditor = (values) => ({
  cellEditor: DropdownCellEditor,
  cellEditorParams: { values },
});

// ---------------------------------------------------------------------------
// Column definitions — 26 visible columns matching v1.7 spreadsheet
// ---------------------------------------------------------------------------

function buildColumns(onCellChanged) {
  const ro  = { editable: false };
  const ref = { ...ro, cellClass: 'row-reference-only' };

  // Cell class for an editable column.
  // isSelect=true  → orange + ▾ arrow  (agSelectCellEditor columns)
  // isSelect=false → plain orange       (free-text columns)
  const editableField = (validKey, isSelect = false) => ({
    cellClass: (p) => {
      if (!p.data.is_configurable) return 'row-reference-only';
      if (validKey && p.data[`valid_${validKey}`] === false) return 'cell-invalid';
      return isSelect ? 'cell-editable-select' : 'cell-editable';
    },
  });

  return [
    // ── Identity (pinned left) ─────────────────────────────────────────────
    { headerName: 'Pin #',        field: 'connector_pin', width: 65,  pinned: 'left', ...ro },
    { headerName: 'Signal Name',  field: 'signal_name',   width: 150, pinned: 'left', ...ro },
    { headerName: 'Ball',         field: 'ball_name',     width: 110, pinned: 'left', ...ro },
    { headerName: 'Verilog Name', field: 'verilog_name',  width: 140, pinned: 'left', ...ro },

    // ── Reference data (visible in v1.7) ───────────────────────────────────
    { headerName: 'DT Pin Name',   field: 'dt_pin_name',  width: 170, ...ref },
    { headerName: 'Power Rail',    field: 'power_rail',   width: 130, ...ref },
    { headerName: 'Wake',          field: 'wake_source',  width: 80,  ...ref },
    { headerName: 'Pad Category',  field: 'pad_category', width: 80,  ...ref },
    { headerName: 'Pull Strength', field: 'pull_strength',width: 90,  ...ref },
    { headerName: 'POR State',     field: 'por_state',    width: 80,  ...ref },

    // ── Customer configuration (editable, cols AS–BH) ──────────────────────
    {
      headerName: 'Customer Usage', field: 'customer_usage', width: 200,
      editable: (p) => !!p.data.is_configurable,
      cellEditor: DropdownCellEditor,
      cellEditorParams: (p) => ({ values: usageOptions(p.data) }),
      cellEditorPopup: true,
      cellEditorPopupPosition: 'under',
      ...editableField('customer_usage', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Pin Direction', field: 'pin_direction', width: 130,
      editable: (p) => !!p.data.is_configurable,
      cellEditor: DropdownCellEditor,
      cellEditorParams: (p) => ({ values: directionOptions(p.data, p.data.customer_usage) }),
      cellEditorPopup: true,
      cellEditorPopupPosition: 'under',
      ...editableField('pin_direction', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Initial State', field: 'initial_state', width: 120,
      editable: (p) => !!p.data.is_configurable,
      ...editableField('initial_state'),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Wake Pin', field: 'wake_pin', width: 85,
      editable: (p) => !!p.data.is_configurable,
      ...dropdownEditor(WAKE_OPTS),
      ...editableField('wake', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'E_IO_OD', field: 'e_io_od', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...dropdownEditor(ENABLE_DISABLE),
      ...editableField('rcv_sel', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'DRV_TYPE', field: 'drv_type', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...dropdownEditor(ENABLE_DISABLE),
      ...editableField(null, true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Int PU (Ω)', field: 'int_pull_up', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Int PD (Ω)', field: 'int_pull_down', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Ext PU (Ω)', field: 'ext_pull_up', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField('resistor'),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Ext PD (Ω)', field: 'ext_pull_down', width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Deep Sleep', field: 'deep_sleep_state', width: 110,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },

    // ── Info (cols BI–BN) ──────────────────────────────────────────────────
    { headerName: 'IO Block V',   field: 'io_block_voltage', width: 90,  ...ref },
    { headerName: 'Net Name',     field: 'net_name',         width: 160, ...ref },
    { headerName: 'Devkit Usage', field: 'devkit_usage',     width: 160, ...ref },
    { headerName: 'Ball Loc.',    field: 'ball_location',    width: 70,  ...ref },
    { headerName: 'Comment',      field: 'comment',          width: 200, ...ref },
  ];
}

// ---------------------------------------------------------------------------
// Row styling
// ---------------------------------------------------------------------------

function getRowClass(params) {
  if (!params.data.is_configurable) return 'row-reference-only';
  if (params.data.is_valid === false) return 'row-invalid';
  return 'row-configurable';
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function PinmuxGrid({ rows, configId, onRowsUpdated }) {
  const gridRef = useRef(null);

  const visibleRows = useMemo(
    () => rows.filter((r) => !r.is_hidden),
    [rows]
  );

  const handleCellChanged = useCallback(async (event) => {
    const { data, colDef, newValue } = event;
    if (!data.is_configurable || !configId) return;

    const field = colDef.field;
    try {
      const { api: gridApi } = gridRef.current;
      // Optimistically update the row
      const updated = { ...data, [field]: newValue };
      const rowNode = gridApi.getRowNode(String(data.sort_order));

      // Import api here to avoid circular dep issues at module level
      const { api } = await import('../api.js');
      const result = await api.updatePin(configId, data.pin_id, { [field]: newValue ?? '' });

      // Merge server response (includes validation flags + direction_options)
      const merged = { ...data, ...result };
      rowNode.setData(merged);
      onRowsUpdated?.();
    } catch (err) {
      console.error('Save failed:', err);
      // Revert
      event.node.setDataValue(field, event.oldValue);
      alert(`Save failed: ${err.message}`);
    }
  }, [configId, onRowsUpdated]);

  const columnDefs = useMemo(
    () => buildColumns(handleCellChanged),
    [handleCellChanged]
  );

  const defaultColDef = useMemo(() => ({
    resizable: true,
    sortable: true,
    filter: true,
    suppressMovable: false,
  }), []);

  return (
    <div className="grid-wrap ag-theme-alpine">
      <AgGridReact
        ref={gridRef}
        rowData={visibleRows}
        columnDefs={columnDefs}
        defaultColDef={defaultColDef}
        getRowId={(p) => String(p.data.sort_order)}
        getRowClass={getRowClass}
        singleClickEdit
        suppressRowClickSelection
        stopEditingWhenCellsLoseFocus
        enableCellTextSelection
        tooltipShowDelay={300}
        rowBuffer={20}
      />
    </div>
  );
}
