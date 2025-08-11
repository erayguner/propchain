import express from 'express';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * @swagger
 * /api/v1/organizations:
 *   get:
 *     summary: List organizations
 *     tags: [Organizations]
 *     responses:
 *       200:
 *         description: List of organizations
 */
router.get('/', asyncHandler(async (req, res) => {
  // Mock response for development
  res.json({
    organizations: [
      {
        id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Acme Property Management',
        slug: 'acme-property'
      }
    ]
  });
}));

export default router;