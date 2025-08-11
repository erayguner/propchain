import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/invoices:
 *   get:
 *     summary: List invoices
 *     tags: [Invoices]
 *     responses:
 *       200:
 *         description: List of invoices
 */
router.get('/', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    invoices: []
  });
}));

export default router;