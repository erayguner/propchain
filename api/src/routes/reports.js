import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/reports/work-summary:
 *   get:
 *     summary: Work summary report
 *     tags: [Reports]
 *     responses:
 *       200:
 *         description: Work summary data
 */
router.get('/work-summary', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    summary: {
      totalJobs: 0,
      completedJobs: 0,
      pendingJobs: 0
    }
  });
}));

export default router;