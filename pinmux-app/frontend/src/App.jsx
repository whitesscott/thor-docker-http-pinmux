import { useState, useEffect, useCallback } from 'react';
import { api } from './api.js';
import { ConfigToolbar } from './components/ConfigToolbar.jsx';
import { PinmuxGrid } from './components/PinmuxGrid.jsx';

export default function App() {
  const [activeConfigId, setActiveId]   = useState(null);
  const [rows, setRows]                 = useState([]);
  const [loading, setLoading]           = useState(false);
  const [error, setError]               = useState(null);
  const [boardName, setBoardName]       = useState('');
  const [exporting, setExporting]       = useState(false);

  // Auto-load the first (DevKit template) config on mount
  useEffect(() => {
    api.listConfigs()
      .then((cfgs) => {
        if (cfgs.length) setActiveId(cfgs[cfgs.length - 1].id);
        else setError('No configurations found — please re-seed the database.');
      })
      .catch((e) => setError(e.message));
  }, []);

  function loadConfig(id) {
    setLoading(true);
    setError(null);
    api.getConfig(id)
      .then(({ config, pins }) => {
        setRows(pins);
        setBoardName(config.board_name || '');
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }

  // Load rows when active config changes
  useEffect(() => {
    if (!activeConfigId) { setRows([]); return; }
    loadConfig(activeConfigId);
  }, [activeConfigId]);

  const handleRowsUpdated = useCallback(() => {
    // Grid rows are updated optimistically; stats re-compute from rows state
  }, []);

  const handleReset = useCallback(async () => {
    if (!activeConfigId) return;
    if (!confirm('Reset all pins to DevKit template defaults? This cannot be undone.')) return;
    setLoading(true);
    try {
      await api.resetConfig(activeConfigId);
      loadConfig(activeConfigId);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  }, [activeConfigId]);

  const stats = rows.length ? {
    total:    rows.filter((r) => r.is_configurable).length,
    errors:   rows.filter((r) => r.is_configurable && r.is_valid === false).length,
    warnings: rows.filter((r) => r.is_configurable && r.customer_usage?.endsWith('*')).length,
  } : null;

  async function handleExport() {
    setExporting(true);
    try {
      const blob = await api.exportDTS(activeConfigId, boardName);
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement('a');
      a.href     = url;
      a.download = `Thor-${boardName || 'custom'}-dts.zip`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      if (err.status === 422) {
        const count = err.data?.invalid?.length ?? '?';
        alert(`Cannot export: ${count} pin(s) have validation errors. Fix them first.`);
      } else {
        alert(`Export failed: ${err.message}`);
      }
    } finally {
      setExporting(false);
    }
  }

  return (
    <div id="root" style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      <header className="app-header">
        <h1>Jetson Thor Pinmux</h1>
        <span style={{ fontSize: 11, color: '#888' }}>
          NVIDIA Tegra264 — Pin Multiplexing Configuration
        </span>
      </header>

      <div className="app-body">
        <ConfigToolbar
          stats={stats}
          boardName={boardName}
          onBoardNameChange={setBoardName}
          onExport={handleExport}
          exporting={exporting}
          onReset={handleReset}
        />

        {error && <div className="error-panel">{error}</div>}

        {loading && (
          <div style={{ padding: 24, color: '#666' }}>Loading configuration…</div>
        )}

        {!loading && activeConfigId && (
          <PinmuxGrid
            rows={rows}
            configId={activeConfigId}
            onRowsUpdated={handleRowsUpdated}
          />
        )}

        {!activeConfigId && !loading && !error && (
          <div style={{ padding: 32, color: '#888', textAlign: 'center' }}>
            Loading…
          </div>
        )}
      </div>
    </div>
  );
}
