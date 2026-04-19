'use strict';

const express = require('express');
const db = require('../db');
const { getUsageOptions, getDirectionOptions } = require('../validation');

const router = express.Router();

/** GET /api/pins — all pin reference data */
router.get('/', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM pins ORDER BY sort_order'
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

/** GET /api/pins/:id — single pin with computed dropdown options */
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db.query('SELECT * FROM pins WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Pin not found' });

    const pin = rows[0];
    res.json({
      ...pin,
      usage_options:     getUsageOptions(pin),
      direction_options: getDirectionOptions(pin, pin.tmpl_customer_usage),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
