import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/documents:
 *   get:
 *     summary: List documents
 *     tags: [Documents]
 *     responses:
 *       200:
 *         description: List of documents
 */
router.get('/', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    documents: []
  });
}));

export default router;