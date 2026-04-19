'use strict';

/**
 * validation.js
 * Port of Sheet26.cls Worksheet_Change validation logic.
 *
 * Each function takes:
 *   pin        – row from the `pins` table (reference data)
 *   pinConfig  – row from `pin_configs` (customer choices)
 *
 * Returns { valid: bool, message: string|null }
 */

function isUnused(customerUsage) {
  return typeof customerUsage === 'string' && customerUsage.startsWith('unused_');
}

function getAllowedDirection(pin, customerUsage) {
  if (customerUsage === pin.mux_gpio)   return pin.allowed_dir_gpio;
  if (customerUsage === pin.mux_sfio0)  return pin.allowed_dir_sfio0;
  if (customerUsage === pin.mux_sfio1)  return pin.allowed_dir_sfio1;
  if (customerUsage === pin.mux_sfio2)  return pin.allowed_dir_sfio2;
  if (customerUsage === pin.mux_sfio3)  return pin.allowed_dir_sfio3;
  return null;
}

/** Mirrors IsCustomerUsageNotBlank */
function validateCustomerUsage(pin, pinConfig) {
  if (!pinConfig.customer_usage) {
    return { valid: false, message: 'Customer Usage cannot be blank' };
  }
  return { valid: true, message: null };
}

/** Mirrors IsPinDirectionValid */
function validatePinDirection(pin, pinConfig) {
  const usage = pinConfig.customer_usage || '';
  const dir   = pinConfig.pin_direction  || '';
  const unused = isUnused(usage);

  if (unused && dir && dir !== 'Not Assigned') {
    return { valid: false, message: 'Cannot assign a pin direction for an unused pin' };
  }
  if (!dir || dir === 'Not Assigned') {
    return { valid: true, message: null };
  }
  const allowed = getAllowedDirection(pin, usage);
  if (allowed === 'I' && dir !== 'Input') {
    return { valid: false, message: `${usage} must be set as Input, not ${dir}` };
  }
  if (allowed === 'O' && dir !== 'Output') {
    return { valid: false, message: `${usage} must be set as Output, not ${dir}` };
  }
  return { valid: true, message: null };
}

/** Mirrors IsInitialStateValid */
function validateInitialState(pin, pinConfig) {
  const usage = pinConfig.customer_usage || '';
  const state = pinConfig.initial_state  || '';
  if (isUnused(usage) && state && state !== 'Z' && state !== 'N/A') {
    return {
      valid: false,
      message: `Initial State for an Unused Pin cannot be assigned to ${state}`,
    };
  }
  return { valid: true, message: null };
}

/** Mirrors IsWakeValid */
function validateWake(pin, pinConfig) {
  const wake  = pinConfig.wake_pin      || '';
  const dir   = pinConfig.pin_direction || '';
  const usage = pinConfig.customer_usage || '';
  if (wake !== 'Yes') return { valid: true, message: null };

  if (isUnused(usage)) {
    return { valid: false, message: 'Wake cannot be enabled on an Unused Pin' };
  }
  if (dir === 'Output') {
    return { valid: false, message: 'Wake cannot be enabled on an Output' };
  }
  if (dir === 'Not Assigned') {
    return { valid: false, message: 'Wake cannot be enabled on an Unassigned pin' };
  }
  return { valid: true, message: null };
}

/** Mirrors IsRCVSELValid (3.3V Tolerance / e_io_od) */
function validateRcvSel(pin, pinConfig) {
  const eIoOd = pinConfig.e_io_od       || '';
  const usage  = pinConfig.customer_usage || '';
  if (eIoOd.toLowerCase() === 'enable' && isUnused(usage)) {
    return { valid: false, message: '3.3V Tolerance cannot be enabled on an Unused Pin' };
  }
  return { valid: true, message: null };
}

/** Mirrors IsResistorConfigurationGood */
function validateResistor(pin, pinConfig) {
  const state = pinConfig.initial_state  || '';
  const extPU = pinConfig.ext_pull_up    || '';
  const extPD = pinConfig.ext_pull_down  || '';

  if (state === 'Int PU' && extPU) {
    return { valid: false, message: 'Internal pull up cannot be enabled if there is an external pull up' };
  }
  if (state === 'Int PU' && extPD) {
    return { valid: false, message: 'Internal pull up cannot be enabled if there is an external pull down' };
  }
  if (state === 'Int PD' && extPU) {
    return { valid: false, message: 'Internal pull down cannot be enabled if there is an external pull up' };
  }
  if (state === 'Int PD' && extPD) {
    return { valid: false, message: 'Internal pull down cannot be enabled if there is an external pull down' };
  }
  return { valid: true, message: null };
}

/**
 * Run all validations and return an object with per-field results plus a
 * flat list of error messages. Mirrors the full Worksheet_Change handler.
 */
function validateAll(pin, pinConfig) {
  const usageResult    = validateCustomerUsage(pin, pinConfig);
  const dirResult      = validatePinDirection(pin, pinConfig);
  const stateResult    = validateInitialState(pin, pinConfig);
  const wakeResult     = validateWake(pin, pinConfig);
  const resistorResult = validateResistor(pin, pinConfig);
  const rcvSelResult   = validateRcvSel(pin, pinConfig);

  const errors = [usageResult, dirResult, stateResult, wakeResult, resistorResult, rcvSelResult]
    .filter((r) => !r.valid)
    .map((r) => r.message);

  // Warning: function name ending in '*' needs NVIDIA AE approval
  const warnings = [];
  const usage = pinConfig.customer_usage || '';
  if (usage.endsWith('*')) {
    warnings.push('Please check with Nvidia AEs before using this function.');
  }

  return {
    valid_customer_usage: usageResult.valid,
    valid_pin_direction:  dirResult.valid,
    valid_initial_state:  stateResult.valid,
    valid_wake:           wakeResult.valid,
    valid_resistor:       resistorResult.valid,
    valid_rcv_sel:        rcvSelResult.valid,
    errors,
    warnings,
  };
}

/** Returns the valid customer_usage dropdown options for a given pin row. */
function getUsageOptions(pin) {
  return [
    pin.mux_unused,
    pin.mux_gpio,
    pin.mux_sfio0,
    pin.mux_sfio1,
    pin.mux_sfio2,
    pin.mux_sfio3,
  ].filter(Boolean);
}

/** Returns valid pin_direction options for the currently selected usage. */
function getDirectionOptions(pin, customerUsage) {
  if (!customerUsage) return [];
  if (isUnused(customerUsage)) return ['Not Assigned'];

  const allowed = getAllowedDirection(pin, customerUsage);
  const options = ['Not Assigned'];
  if (!allowed || allowed === 'B') {
    options.push('Input', 'Output', 'Bidirectional', 'Open-Drain');
  } else if (allowed === 'I') {
    options.push('Input');
  } else if (allowed === 'O') {
    options.push('Output', 'Open-Drain');
  }
  return options;
}

module.exports = {
  validateAll,
  validateCustomerUsage,
  validatePinDirection,
  validateInitialState,
  validateWake,
  validateResistor,
  validateRcvSel,
  getUsageOptions,
  getDirectionOptions,
  isUnused,
};
