import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/properties:
 *   get:
 *     summary: List properties
 *     tags: [Properties]
 *     responses:
 *       200:
 *         description: List of properties
 */
router.get('/', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    properties: []
  });
}));

export default router;