'use strict';

const express  = require('express');
const archiver = require('archiver');
const db       = require('../db');
const { generateDTS } = require('../dts');

const router = express.Router();

/**
 * POST /api/configurations/:id/export/dts
 * Body: { board_name?: string }  (overrides the config's board_name)
 *
 * Generates three .dtsi files and streams them as a ZIP download.
 */
router.post('/:id/export/dts', async (req, res, next) => {
  try {
    // 1. Load configuration metadata
    const configRes = await db.query(
      'SELECT * FROM configurations WHERE id = $1',
      [req.params.id]
    );
    if (!configRes.rows.length) return res.status(404).json({ error: 'Configuration not found' });
    const config = configRes.rows[0];

    const boardName = (req.body.board_name || config.board_name || 'custom')
      .toLowerCase()
      .replace(/\s+/g, '-');
    const revision = String(config.revision);

    // 2. Load configurable pin rows (joined with pin reference)
    const pinsRes = await db.query(`
      SELECT
        pc.*,
        p.dt_pin_name, p.ball_name, p.func_safe,
        p.mux_gpio,    p.mux_sfio0, p.mux_sfio1, p.mux_sfio2, p.mux_sfio3,
        p.mux_unused,
        p.default_pupd, p.default_tristate, p.default_e_input, p.default_gpio_init
      FROM pin_configs pc
      JOIN pins p ON p.id = pc.pin_id
      WHERE pc.config_id = $1
        AND p.is_configurable = TRUE
      ORDER BY p.sort_order
    `, [req.params.id]);

    // 3. Load pad voltage settings
    const pvRes = await db.query(`
      SELECT pvr.voltage_rail, pvc.voltage_setting
      FROM pad_voltage_configs pvc
      JOIN pad_voltage_rails pvr ON pvr.id = pvc.rail_id
      WHERE pvc.config_id = $1
      ORDER BY pvr.voltage_rail
    `, [req.params.id]);

    // 4. Check for invalid pins
    const invalid = pinsRes.rows.filter((r) => r.is_valid === false);
    if (invalid.length > 0) {
      // Still allow export but include a warning header in the response
      // (mirrors the VBA SanityCheck which blocks on INVALID cells)
      // We return a 422 with details so the UI can decide whether to proceed.
      return res.status(422).json({
        error:   'Configuration has validation errors',
        invalid: invalid.map((r) => ({
          pin_id:    r.pin_id,
          ball_name: r.ball_name,
        })),
      });
    }

    // 5. Generate DTS content
    const dts = generateDTS(boardName, revision, pinsRes.rows, pvRes.rows);

    // 6. Stream as ZIP
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="Thor-${boardName}-dts.zip"`
    );

    const archive = archiver('zip', { zlib: { level: 6 } });
    archive.on('error', next);
    archive.pipe(res);

    archive.append(dts.pinmuxFile,     { name: dts.pinmuxFilename });
    archive.append(dts.gpioFile,       { name: dts.gpioFilename });
    archive.append(dts.padVoltageFile, { name: dts.padVoltageFilename });

    await archive.finalize();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
