'use strict';

/**
 * dts.js
 * Port of Generate_Device_Tree.bas.
 *
 * generateDTS(rows) → { pinmux, gpio, padVoltage }  (three file contents as strings)
 *
 * rows: array of objects joining pin_configs + pins, with pad voltage entries appended.
 *       Each row has all pins columns plus pin_configs columns.
 */

const T = '\t';
const TT = '\t\t';
const TTT = '\t\t\t';
const TTTT = '\t\t\t\t';

const COPYRIGHT = `\
/*
 * SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */`;

// ---------------------------------------------------------------------------
// Field-value → DTS constant mapping
// ---------------------------------------------------------------------------

function getPull(pupd) {
  const v = (pupd || 'NORMAL').toUpperCase();
  if (v === 'PULL_DOWN') return 'TEGRA_PIN_PULL_DOWN';
  if (v === 'PULL_UP')   return 'TEGRA_PIN_PULL_UP';
  return 'TEGRA_PIN_PULL_NONE';
}

function getTristate(tristate) {
  return (tristate || '').toUpperCase() === 'TRISTATE'
    ? 'TEGRA_PIN_ENABLE'
    : 'TEGRA_PIN_DISABLE';
}

function getEInput(eInput) {
  return (eInput || '').toUpperCase() === 'ENABLE'
    ? 'TEGRA_PIN_ENABLE'
    : 'TEGRA_PIN_DISABLE';
}

function getLPDR(drvType) {
  const v = (drvType || '').toUpperCase();
  if (v === 'ENABLE')  return 'TEGRA_PIN_2X_DRIVER';
  if (v === 'DEF_1X')  return 'TEGRA_PIN_DEFAULT_DRIVE_1X';
  if (v === 'DEF_2X')  return 'TEGRA_PIN_DEFAULT_DRIVE_2X';
  return 'TEGRA_PIN_1X_DRIVER';     // DISABLE or empty → normal/1x driver
}

function getTegraBool(val) {
  return (val || '').toLowerCase() === 'enable'
    ? 'TEGRA_PIN_ENABLE'
    : 'TEGRA_PIN_DISABLE';
}

// ---------------------------------------------------------------------------
// GPIO port → controller type
// ---------------------------------------------------------------------------

const FSI_PORTS  = new Set(['AB','AC','AD','AE','AF','AG','AH','AJ']);
const AON_PORTS  = new Set(['AA','BB','CC','DD','EE']);
const UPHY_PORTS = new Set(['A','B','C','D','E']);

const GPIO_ADDRESSES = {
  MAIN: 'gpio@ac300000',
  UPHY: 'gpio@e8300000',
  AON:  'gpio@8cf00000',
  FSI:  'gpio@b0320000',
};

/**
 * Parse a mux_gpio value like "GPIO3_PAA.04" into { portName, pinIndex, gpioType }.
 * Returns null if the value doesn't look like a GPIO3_ pin.
 */
function parseGPIOName(muxGpio) {
  if (!muxGpio || !muxGpio.startsWith('GPIO3_P')) return null;
  // "GPIO3_PAA.04" → strip "GPIO3_P" prefix and ".NN" suffix
  const inner = muxGpio.slice('GPIO3_P'.length);          // "AA.04"
  const dotIdx = inner.lastIndexOf('.');
  if (dotIdx < 0) return null;
  const portName = inner.slice(0, dotIdx).toUpperCase();  // "AA"
  const pinIndex = inner.slice(dotIdx + 1);               // "04" → last char = "4"
  const idx = pinIndex.slice(-1);                          // single digit (max port width = 8)

  let gpioType;
  if (portName.length === 2 && FSI_PORTS.has(portName))  gpioType = 'FSI';
  else if (portName.length === 2 && AON_PORTS.has(portName)) gpioType = 'AON';
  else if (portName.length === 1 && UPHY_PORTS.has(portName)) gpioType = 'UPHY';
  else gpioType = 'MAIN';

  return { portName, pinIndex: idx, gpioType };
}

function gpioMacro(portName, pinIndex, gpioType) {
  return `TEGRA264_${gpioType}_GPIO(${portName}, ${pinIndex})`;
}

// ---------------------------------------------------------------------------
// Pin classification
// ---------------------------------------------------------------------------

function isGPIOUsage(usage) {
  return typeof usage === 'string' && usage.startsWith('GPIO3_');
}

function isUnusedUsage(usage) {
  return typeof usage === 'string' && usage.startsWith('unused_');
}

/**
 * Return the DTS function string for a pin.
 * Mirrors the VBA SFIOName logic:
 *   - unused or GPIO → func_safe (lowercase)
 *   - SFIO → customer_usage (lowercase)
 */
function getDTSFunction(pin, pc) {
  const usage = pc.customer_usage || '';
  if (isUnusedUsage(usage) || isGPIOUsage(usage)) {
    return (pin.func_safe || '').toLowerCase();
  }
  return usage.toLowerCase();
}

// ---------------------------------------------------------------------------
// Pinmux DTS block builder
// ---------------------------------------------------------------------------

function buildPinBlock(pin, pc) {
  const name = pin.dt_pin_name || pin.ball_name;
  const fn   = getDTSFunction(pin, pc);
  const pull      = getPull(pc.pupd      || pin.default_pupd);
  const tristate  = getTristate(pc.tristate || pin.default_tristate);
  const eInput    = getEInput(pc.e_input  || pin.default_e_input);
  const lpdr      = getLPDR(pc.drv_type);

  let block = `${TTT}${name} {\n`;
  block += `${TTTT}nvidia,pins = "${name}";\n`;
  block += `${TTTT}nvidia,function = "${fn}";\n`;
  block += `${TTTT}nvidia,pull = <${pull}>;\n`;
  block += `${TTTT}nvidia,tristate = <${tristate}>;\n`;
  block += `${TTTT}nvidia,enable-input = <${eInput}>;\n`;
  block += `${TTTT}nvidia,drv-type = <${lpdr}>;\n`;

  if ((pc.lock || '').toLowerCase() === 'enable') {
    block += `${TTTT}nvidia,lock = <TEGRA_PIN_ENABLE>;\n`;
  }
  // Open-drain (from pin_direction)
  if ((pc.pin_direction || '') === 'Open-Drain') {
    block += `${TTTT}nvidia,open-drain = <TEGRA_PIN_ENABLE>;\n`;
  }
  // 3.3V tolerance / RCV_SEL (e_io_od)
  if (pc.e_io_od) {
    block += `${TTTT}nvidia,e-io-od = <${getTegraBool(pc.e_io_od)}>;\n`;
  }
  // EQOS loopback
  if (pc.e_lpbk) {
    block += `${TTTT}nvidia,e-lpbk = <${getTegraBool(pc.e_lpbk)}>;\n`;
  }

  // Pull resistor values — documented as comments (not SoC-register-programmable DTS properties)
  const resParts = [];
  if (pc.int_pull_up)   resParts.push(`int-pu: ${pc.int_pull_up}`);
  if (pc.int_pull_down) resParts.push(`int-pd: ${pc.int_pull_down}`);
  if (pc.ext_pull_up)   resParts.push(`ext-pu: ${pc.ext_pull_up}`);
  if (pc.ext_pull_down) resParts.push(`ext-pd: ${pc.ext_pull_down}`);
  if (resParts.length) {
    block += `${TTTT}/* ${resParts.join('; ')} */\n`;
  }

  block += `${TTT}};\n`;
  return block;
}

// ---------------------------------------------------------------------------
// Main generator
// ---------------------------------------------------------------------------

/**
 * @param {string} boardName  lower-case board identifier
 * @param {string} revision   revision string (e.g. "39")
 * @param {Array}  pinRows    joined pin + pin_config rows (is_configurable=true only)
 * @param {Array}  padVoltageRows  { voltage_rail, voltage_setting }[]
 * @returns {{ pinmuxFile, gpioFile, padVoltageFile, pinmuxFilename, gpioFilename, padVoltageFilename }}
 */
function generateDTS(boardName, revision, pinRows, padVoltageRows) {
  const pinmuxFilename     = `Thor-${boardName}-pinmux.dtsi`;
  const gpioFilename       = `Thor-${boardName}-gpio-default.dtsi`;
  const padVoltageFilename = `Thor-${boardName}-padvoltage-default.dtsi`;

  // Classify pins
  const sfio    = [];
  const gpio    = [];
  const unused  = [];

  for (const r of pinRows) {
    const usage = r.customer_usage || r.tmpl_customer_usage || '';
    if (isUnusedUsage(usage))       unused.push(r);
    else if (isGPIOUsage(usage))    gpio.push(r);
    else                            sfio.push(r);
  }

  // ---- Pinmux file --------------------------------------------------------
  let pm = `/*This dtsi file was generated by ${boardName}.xlsm Revision: ${revision} */\n`;
  pm += COPYRIGHT + '\n\n';
  pm += `#include "t264-pinctrl-tegra.h"\n\n`;
  pm += `#include "./${gpioFilename}"\n\n`;
  pm += `pinmux@ac281000 {\n`;
  pm += `${TT}common {\n`;
  pm += `${TTT}/* SFIO Pin Configuration */\n`;

  for (let i = 0; i < sfio.length + gpio.length; i++) {
    const r = i < sfio.length ? sfio[i] : gpio[i - sfio.length];
    if (i === sfio.length) pm += `${TTT}/* GPIO Pin Configuration */\n`;
    pm += buildPinBlock(r, r) + (i < sfio.length + gpio.length - 1 ? '\n' : '');
  }

  pm += `${TT}};\n\n`;
  pm += `${T}pinmux_unused_lowpower: unused_lowpower {\n`;

  for (const r of unused) {
    pm += buildPinBlock(r, r);
  }

  pm += `${TT}};\n\n`;
  pm += `${TT}drive_default: drive {\n`;
  pm += `${TT}};\n`;
  pm += `};\n`;

  // ---- GPIO file ----------------------------------------------------------
  let gp = `/*This dtsi file was generated by ${boardName}.xlsm Revision: ${revision} */\n`;
  gp += COPYRIGHT + '\n\n';
  gp += `#include "tegra264-gpio.h"\n\n`;

  for (const gpioType of ['MAIN', 'UPHY', 'AON', 'FSI']) {
    const typeRows = gpio.filter((r) => {
      const parsed = parseGPIOName(r.mux_gpio);
      return parsed && parsed.gpioType === gpioType;
    });

    const inputs   = [];
    const outLow   = [];
    const outHigh  = [];

    for (const r of typeRows) {
      const parsed = parseGPIOName(r.mux_gpio);
      if (!parsed) continue;
      const macro    = gpioMacro(parsed.portName, parsed.pinIndex, gpioType);
      const initVal  = r.gpio_init || r.default_gpio_init || '';
      const eInputOn = (r.e_input || r.default_e_input || '').toUpperCase() === 'ENABLE';

      if (initVal === '1')       outHigh.push(macro);
      else if (initVal === '0')  outLow.push(macro);
      else if (eInputOn)         inputs.push(macro);
    }

    gp += `${GPIO_ADDRESSES[gpioType]} {\n`;
    gp += `${T} default {\n`;
    gp += `${TT}gpio-input = <\n`;
    for (const m of inputs) gp += `${TTT}${m}\n`;
    gp += `${TT}>;\n`;
    gp += `${TT}gpio-output-low = <\n`;
    for (const m of outLow) gp += `${TTT}${m}\n`;
    gp += `${TT}>;\n`;
    gp += `${TT}gpio-output-high = <\n`;
    for (const m of outHigh) gp += `${TTT}${m}\n`;
    gp += `${TT}>;\n`;
    gp += `${T}};\n};\n\n`;
  }

  // ---- Pad voltage file ---------------------------------------------------
  let pv = `/*This dtsi file was generated by ${boardName}.xlsm Revision: ${revision} */\n`;
  pv += COPYRIGHT + '\n\n';
  pv += `#define IO_PAD_VOLTAGE_1_2V 1200000\n`;
  pv += `#define IO_PAD_VOLTAGE_1_8V 1800000\n`;
  pv += `#define IO_PAD_VOLTAGE_3_3V 3300000\n\n`;
  pv += `pmc@8c800000 {\n`;
  pv += `${T}io-pad-defaults {\n`;

  for (const { voltage_rail, voltage_setting } of padVoltageRows) {
    const railName = voltage_rail.toLowerCase();
    let macro;
    if (voltage_setting === '1.2V')                     macro = 'IO_PAD_VOLTAGE_1_2V';
    else if (voltage_setting.startsWith('1.8V'))        macro = 'IO_PAD_VOLTAGE_1_8V';
    else                                                macro = 'IO_PAD_VOLTAGE_3_3V';

    pv += `${TT}${railName} {\n`;
    pv += `${TTT}nvidia,io-pad-init-voltage = <${macro}>;\n`;
    pv += `${TT}};\n\n`;
  }

  pv += `${T}};\n};\n`;

  return {
    pinmuxFilename,
    gpioFilename,
    padVoltageFilename,
    pinmuxFile:     pm,
    gpioFile:       gp,
    padVoltageFile: pv,
  };
}

module.exports = { generateDTS };
