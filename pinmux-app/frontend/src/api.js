const BASE = '/api';

async function request(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 204) return null;
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data.error || 'Request failed'), { data, status: res.status });
  return data;
}

export const api = {
  // Pins
  getPins:   () => request('GET', '/pins'),

  // Configurations
  listConfigs:  ()       => request('GET', '/configurations'),
  getConfig:    (id)     => request('GET', `/configurations/${id}`),
  createConfig: (body)   => request('POST', '/configurations', body),
  updateConfig: (id, b)  => request('PUT',  `/configurations/${id}`, b),
  deleteConfig: (id)     => request('DELETE', `/configurations/${id}`),

  // Per-pin update
  updatePin: (configId, pinId, fields) =>
    request('PUT', `/configurations/${configId}/pins/${pinId}`, fields),

  // Reset config to DevKit template defaults
  resetConfig: (id) => request('POST', `/configurations/${id}/reset`),

  // Pad voltage
  getPadVoltage:    (configId)                => request('GET', `/configurations/${configId}/pad-voltage`),
  updatePadVoltage: (configId, railId, body)  => request('PUT', `/configurations/${configId}/pad-voltage/${railId}`, body),

  // DTS export (returns a Blob)
  exportDTS: async (configId, boardName) => {
    const res = await fetch(`${BASE}/configurations/${configId}/export/dts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ board_name: boardName }),
    });
    if (!res.ok) {
      const data = await res.json();
      throw Object.assign(new Error(data.error || 'Export failed'), { data, status: res.status });
    }
    return res.blob();
  },
};
