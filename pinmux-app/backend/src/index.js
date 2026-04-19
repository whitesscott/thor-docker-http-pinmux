'use strict';

require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const pinsRouter          = require('./routes/pins');
const configurationsRouter = require('./routes/configurations');
const exportRouter        = require('./routes/export');

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.use('/api/pins',           pinsRouter);
app.use('/api/configurations', configurationsRouter);
app.use('/api/configurations', exportRouter);

// Generic error handler
app.use((err, req, res, _next) => {
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Pinmux API listening on http://localhost:${PORT}`);
});
