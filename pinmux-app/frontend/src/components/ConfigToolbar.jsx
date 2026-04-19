export function ConfigToolbar({
  stats, boardName, onBoardNameChange,
  onExport, exporting, onReset,
}) {
  return (
    <div className="toolbar">
      <label>Board name:</label>
      <input
        value={boardName}
        onChange={(e) => onBoardNameChange(e.target.value)}
        placeholder="jetson-thor-devkit"
        style={{ width: 180 }}
      />

      <button className="primary" onClick={onExport} disabled={exporting}>
        {exporting ? 'Generating…' : '⬇ Export DTS'}
      </button>

      <button className="danger" onClick={onReset}>Reset</button>

      <span style={{ flex: 1 }} />

      {stats && (
        <>
          <span className="stat-badge">{stats.total} pins</span>
          {stats.errors > 0 && (
            <span className="stat-badge error">{stats.errors} errors</span>
          )}
          {stats.warnings > 0 && (
            <span className="stat-badge warn">{stats.warnings} warnings</span>
          )}
        </>
      )}
    </div>
  );
}
