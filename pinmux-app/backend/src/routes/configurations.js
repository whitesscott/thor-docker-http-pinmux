'use strict';

const express = require('express');
const db = require('../db');
const { validateAll, getUsageOptions, getDirectionOptions } = require('../validation');

const router = express.Router();

// ---------------------------------------------------------------------------
// Configuration CRUD
// ---------------------------------------------------------------------------

/** GET /api/configurations */
router.get('/', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM configurations ORDER BY updated_at DESC'
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

/** GET /api/configurations/:id  — config metadata + all pin_configs joined with pin reference */
router.get('/:id', async (req, res, next) => {
  try {
    const configRes = await db.query(
      'SELECT * FROM configurations WHERE id = $1',
      [req.params.id]
    );
    if (!configRes.rows.length) return res.status(404).json({ error: 'Configuration not found' });
    const config = configRes.rows[0];

    const pinsRes = await db.query(`
      SELECT
        pc.*,
        p.sort_order,   p.row_number,   p.xlsm_row,    p.is_configurable,
        p.connector_pin, p.signal_name,  p.ball_name,       p.verilog_name,
        p.mux_unused,   p.mux_gpio,
        p.mux_sfio0,    p.mux_sfio1,    p.mux_sfio2,       p.mux_sfio3,
        p.allowed_dir_gpio, p.allowed_dir_sfio0, p.allowed_dir_sfio1,
        p.allowed_dir_sfio2, p.allowed_dir_sfio3,
        p.func_f0, p.func_f1, p.func_f2, p.func_f3, p.func_safe,
        p.dt_pin_name,  p.power_rail,   p.wake_source,     p.strap,
        p.gte,          p.dpd_control,  p.dpd_group,
        p.pad_category, p.pad_type,     p.pull_strength,   p.por_state,
        p.is_hidden,
        p.drv_type_applicable,
        p.io_block_voltage, COALESCE(pc.net_name, p.net_name) AS net_name, p.devkit_usage, p.gpio_true_direction, p.comment,
        COALESCE(pc.ball_location, p.ball_location) AS ball_location,
        p.default_pupd, p.default_tristate, p.default_e_input, p.default_gpio_init,
        p.tmpl_customer_usage, p.tmpl_pin_direction
      FROM pins p
      LEFT JOIN pin_configs pc ON pc.pin_id = p.id AND pc.config_id = $1
      WHERE (NOT p.is_configurable AND p.xlsm_row IS NOT NULL) OR pc.id IS NOT NULL
      ORDER BY p.sort_order
    `, [req.params.id]);

    // Attach dropdown options to each row
    const pins = pinsRes.rows.map((row) => ({
      ...row,
      usage_options:     getUsageOptions(row),
      direction_options: getDirectionOptions(row, row.customer_usage),
    }));

    res.json({ config, pins });
  } catch (err) {
    next(err);
  }
});

/** POST /api/configurations — create new config, optionally seeded from a template */
router.post('/', async (req, res, next) => {
  const { name, board_name, notes, seed_from_config_id } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const configRes = await client.query(
      `INSERT INTO configurations (name, board_name, notes)
       VALUES ($1, $2, $3) RETURNING *`,
      [name, board_name || null, notes || null]
    );
    const newConfig = configRes.rows[0];

    if (seed_from_config_id) {
      // Copy pin_configs from the specified source configuration
      await client.query(`
        INSERT INTO pin_configs (
          config_id, pin_id,
          pupd, tristate, e_input, gpio_init,
          customer_usage, pin_direction, initial_state,
          wake_pin, lock, e_io_od, drv_type, e_lpbk,
          e_18v, schmitt, e_hsrx18v,
          int_pull_up, int_pull_down, ext_pull_up, ext_pull_down, deep_sleep_state,
          valid_customer_usage, valid_pin_direction, valid_initial_state,
          valid_wake, valid_resistor, valid_rcv_sel
        )
        SELECT
          $1, pin_id,
          pupd, tristate, e_input, gpio_init,
          customer_usage, pin_direction, initial_state,
          wake_pin, lock, e_io_od, drv_type, e_lpbk,
          e_18v, schmitt, e_hsrx18v,
          int_pull_up, int_pull_down, ext_pull_up, ext_pull_down, deep_sleep_state,
          valid_customer_usage, valid_pin_direction, valid_initial_state,
          valid_wake, valid_resistor, valid_rcv_sel
        FROM pin_configs
        WHERE config_id = $2
      `, [newConfig.id, seed_from_config_id]);
    } else {
      // Seed from the DevKit template values stored on the pins table
      await client.query(`
        INSERT INTO pin_configs (
          config_id, pin_id,
          pupd, tristate, e_input, gpio_init,
          customer_usage, pin_direction, initial_state,
          wake_pin, lock, e_io_od, drv_type, e_lpbk,
          e_18v, schmitt, e_hsrx18v,
          int_pull_up, int_pull_down, ext_pull_up, ext_pull_down, deep_sleep_state
        )
        SELECT
          $1, p.id,
          p.default_pupd, p.default_tristate, p.default_e_input, p.default_gpio_init,
          p.tmpl_customer_usage, p.tmpl_pin_direction, p.tmpl_initial_state,
          p.tmpl_wake_pin, p.tmpl_lock, p.tmpl_e_io_od, p.tmpl_drv_type, p.tmpl_e_lpbk,
          p.tmpl_e_18v, p.tmpl_schmitt, p.tmpl_e_hsrx18v,
          p.tmpl_int_pull_up, p.tmpl_int_pull_down,
          p.tmpl_ext_pull_up, p.tmpl_ext_pull_down, p.tmpl_deep_sleep_state
        FROM pins p
        WHERE p.is_configurable = TRUE
        ORDER BY p.sort_order
      `, [newConfig.id]);
    }

    // Also seed pad voltage from the rails table
    await client.query(`
      INSERT INTO pad_voltage_configs (config_id, rail_id, voltage_setting)
      SELECT $1, id, default_setting FROM pad_voltage_rails
    `, [newConfig.id]);

    await client.query('COMMIT');
    res.status(201).json(newConfig);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

/** PUT /api/configurations/:id — update config metadata */
router.put('/:id', async (req, res, next) => {
  const { name, board_name, notes } = req.body;
  try {
    const { rows } = await db.query(
      `UPDATE configurations
       SET name = COALESCE($1, name),
           board_name = COALESCE($2, board_name),
           notes = COALESCE($3, notes),
           updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [name, board_name, notes, req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Configuration not found' });
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

/** DELETE /api/configurations/:id */
router.delete('/:id', async (req, res, next) => {
  try {
    const { rowCount } = await db.query(
      'DELETE FROM configurations WHERE id = $1',
      [req.params.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Configuration not found' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// Per-pin config update
// ---------------------------------------------------------------------------

/**
 * PUT /api/configurations/:id/pins/:pinId
 * Updates one pin_config row, re-runs validation, returns the updated row.
 * Body: any subset of the pin_config editable fields.
 */
router.put('/:id/pins/:pinId', async (req, res, next) => {
  const { id: configId, pinId } = req.params;

  // Fields the client is allowed to set
  const EDITABLE = [
    'pupd', 'tristate', 'e_input', 'gpio_init',
    'customer_usage', 'pin_direction', 'initial_state',
    'wake_pin', 'lock', 'e_io_od', 'drv_type', 'e_lpbk',
    'e_18v', 'schmitt', 'e_hsrx18v',
    'int_pull_up', 'int_pull_down', 'ext_pull_up', 'ext_pull_down', 'deep_sleep_state',
    'net_name', 'ball_location',
  ];

  const updates = {};
  for (const field of EDITABLE) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates[field] = req.body[field] === '' ? null : req.body[field];
    }
  }
  if (!Object.keys(updates).length) {
    return res.status(400).json({ error: 'No editable fields provided' });
  }

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    // Apply the field updates
    const setClause = Object.keys(updates)
      .map((k, i) => `${k} = $${i + 1}`)
      .join(', ');
    const values = [...Object.values(updates), configId, pinId];
    const updateRes = await client.query(
      `UPDATE pin_configs
       SET ${setClause}
       WHERE config_id = $${values.length - 1} AND pin_id = $${values.length}
       RETURNING *`,
      values
    );
    if (!updateRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Pin config not found' });
    }
    const pc = updateRes.rows[0];

    // Load the pin reference row for validation
    const pinRes = await client.query('SELECT * FROM pins WHERE id = $1', [pinId]);
    const pin = pinRes.rows[0];

    // Re-run validation
    const v = validateAll(pin, pc);
    await client.query(
      `UPDATE pin_configs
       SET valid_customer_usage = $1,
           valid_pin_direction  = $2,
           valid_initial_state  = $3,
           valid_wake           = $4,
           valid_resistor       = $5,
           valid_rcv_sel        = $6
       WHERE config_id = $7 AND pin_id = $8`,
      [
        v.valid_customer_usage, v.valid_pin_direction, v.valid_initial_state,
        v.valid_wake, v.valid_resistor, v.valid_rcv_sel,
        configId, pinId,
      ]
    );

    await client.query(
      'UPDATE configurations SET updated_at = NOW() WHERE id = $1',
      [configId]
    );

    await client.query('COMMIT');

    res.json({
      ...pc,
      valid_customer_usage: v.valid_customer_usage,
      valid_pin_direction:  v.valid_pin_direction,
      valid_initial_state:  v.valid_initial_state,
      valid_wake:           v.valid_wake,
      valid_resistor:       v.valid_resistor,
      valid_rcv_sel:        v.valid_rcv_sel,
      is_valid:             v.valid_customer_usage && v.valid_pin_direction &&
                            v.valid_initial_state  && v.valid_wake &&
                            v.valid_resistor       && v.valid_rcv_sel,
      errors:   v.errors,
      warnings: v.warnings,
      direction_options: getDirectionOptions(pin, pc.customer_usage),
    });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

// ---------------------------------------------------------------------------
// Reset to template defaults
// ---------------------------------------------------------------------------

/** POST /api/configurations/:id/reset — restore all pin_configs to DevKit template values */
router.post('/:id/reset', async (req, res, next) => {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    await client.query(`
      UPDATE pin_configs pc
      SET
        pupd             = p.default_pupd,
        tristate         = p.default_tristate,
        e_input          = p.default_e_input,
        gpio_init        = p.default_gpio_init,
        customer_usage   = p.tmpl_customer_usage,
        pin_direction    = p.tmpl_pin_direction,
        initial_state    = p.tmpl_initial_state,
        wake_pin         = p.tmpl_wake_pin,
        lock             = p.tmpl_lock,
        e_io_od          = p.tmpl_e_io_od,
        drv_type         = p.tmpl_drv_type,
        e_lpbk           = p.tmpl_e_lpbk,
        e_18v            = p.tmpl_e_18v,
        schmitt          = p.tmpl_schmitt,
        e_hsrx18v        = p.tmpl_e_hsrx18v,
        int_pull_up      = p.tmpl_int_pull_up,
        int_pull_down    = p.tmpl_int_pull_down,
        ext_pull_up      = p.tmpl_ext_pull_up,
        ext_pull_down    = p.tmpl_ext_pull_down,
        deep_sleep_state = p.tmpl_deep_sleep_state,
        valid_customer_usage = NULL,
        valid_pin_direction  = NULL,
        valid_initial_state  = NULL,
        valid_wake           = NULL,
        valid_resistor       = NULL,
        valid_rcv_sel        = NULL
      FROM pins p
      WHERE pc.pin_id = p.id AND pc.config_id = $1
    `, [req.params.id]);
    await client.query(
      'UPDATE configurations SET updated_at = NOW() WHERE id = $1',
      [req.params.id]
    );
    await client.query('COMMIT');
    res.status(204).end();
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

// ---------------------------------------------------------------------------
// Pad voltage
// ---------------------------------------------------------------------------

/** GET /api/configurations/:id/pad-voltage */
router.get('/:id/pad-voltage', async (req, res, next) => {
  try {
    const { rows } = await db.query(`
      SELECT pvc.*, pvr.voltage_rail
      FROM pad_voltage_configs pvc
      JOIN pad_voltage_rails pvr ON pvr.id = pvc.rail_id
      WHERE pvc.config_id = $1
      ORDER BY pvr.voltage_rail
    `, [req.params.id]);
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

/** PUT /api/configurations/:id/pad-voltage/:railId */
router.put('/:id/pad-voltage/:railId', async (req, res, next) => {
  const { voltage_setting } = req.body;
  if (!voltage_setting) return res.status(400).json({ error: 'voltage_setting is required' });
  try {
    const { rows } = await db.query(
      `UPDATE pad_voltage_configs SET voltage_setting = $1
       WHERE config_id = $2 AND rail_id = $3 RETURNING *`,
      [voltage_setting, req.params.id, req.params.railId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Pad voltage config not found' });
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
