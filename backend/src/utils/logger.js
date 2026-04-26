// ============ utils/logger.js ============
const winston = require('winston');
const path    = require('path');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message }) => `${timestamp} [${level}] ${message}`)
      ),
    }),
    new winston.transports.File({ filename: path.join('logs', 'error.log'), level: 'error', maxsize: 5242880, maxFiles: 3 }),
    new winston.transports.File({ filename: path.join('logs', 'combined.log'), maxsize: 10485760, maxFiles: 5 }),
  ],
});

module.exports = logger;
