import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/work-logs:
 *   get:
 *     summary: List work logs
 *     tags: [Work Logs]
 *     responses:
 *       200:
 *         description: List of work logs
 */
router.get('/', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    workLogs: []
  });
}));

export default router;