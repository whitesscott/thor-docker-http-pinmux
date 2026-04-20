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

  return [
    // ── Identity (pinned left) ─────────────────────────────────────────────
    { headerName: 'Pin #', field: 'connector_pin', width: 65, pinned: 'left', ...ro },
    { headerName: 'Signal Name', field: 'signal_name', width: 150, pinned: 'left', ...ro },
    { headerName: 'Ball', field: 'ball_name', width: 110, pinned: 'left', ...ro },
    { headerName: 'Verilog Name', field: 'verilog_name', width: 140, pinned: 'left', ...ro },

    // ── Reference data ─────────────────────────────────────────────────────
    { headerName: 'DT Pin Name', field: 'dt_pin_name', width: 170, ...ref },
    { headerName: 'Power Rail', field: 'power_rail', width: 130, ...ref },
    { headerName: 'Wake', field: 'wake_source', width: 80, ...ref },
    { headerName: 'Pad Category', field: 'pad_category', width: 80, ...ref },
    { headerName: 'Pull Strength', field: 'pull_strength', width: 90, ...ref },
    { headerName: 'POR State', field: 'por_state', width: 80, ...ref },

    // ── Customer configuration (editable) ──────────────────────────────────
    {
      headerName: 'Customer Usage',
      field: 'customer_usage',
      width: 200,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor((data) => usageOptions(data)),
      ...editableField('customer_usage', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Pin Direction',
      field: 'pin_direction',
      width: 130,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor((data) => directionOptions(data, data.customer_usage)),
      ...editableField('pin_direction', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Initial State',
      field: 'initial_state',
      width: 120,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor(INITIAL_STATE),
      ...editableField('initial_state', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Wake Pin',
      field: 'wake_pin',
      width: 85,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor(WAKE_OPTS),
      ...editableField('wake', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'E_IO_OD',
      field: 'e_io_od',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor(ENABLE_DISABLE),
      ...editableField('rcv_sel', true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'DRV_TYPE',
      field: 'drv_type',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...selectEditor(ENABLE_DISABLE),
      ...editableField(null, true),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Int PU (Ω)',
      field: 'int_pull_up',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Int PD (Ω)',
      field: 'int_pull_down',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Ext PU (Ω)',
      field: 'ext_pull_up',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField('resistor'),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Ext PD (Ω)',
      field: 'ext_pull_down',
      width: 90,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },
    {
      headerName: 'Deep Sleep',
      field: 'deep_sleep_state',
      width: 110,
      editable: (p) => !!p.data.is_configurable,
      ...editableField(null),
      onCellValueChanged: onCellChanged,
    },

    // ── Info ────────────────────────────────────────────────────────────────
    { headerName: 'IO Block V', field: 'io_block_voltage', width: 90, ...ref },
    { headerName: 'Net Name', field: 'net_name', width: 160, ...ref },
    { headerName: 'Devkit Usage', field: 'devkit_usage', width: 160, ...ref },
    { headerName: 'Ball Loc.', field: 'ball_location', width: 70, ...ref },
    { headerName: 'Comment', field: 'comment', width: 200, ...ref },
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
  const visibleRows = useMemo(
    () => rows.filter((r) => !r.is_hidden),
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
        rowSelection={{ enableClickSelection: false }}
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

