import { Router, Request, Response } from 'express';
import { verificationService } from '../services/verificationService';
import { otpService } from '../services/otpService';

const router = Router();

/**
 * GET /api/verification/harvester/status/:harvesterId
 * Retrieve current verification workflow status for a harvester
 */
router.get('/harvester/status/:harvesterId', async (req: Request, res: Response) => {
  try {
    const harvesterId = String(req.params.harvesterId);
    const verification = await verificationService.getOrCreateVerification(harvesterId);
    res.json({ success: true, verification });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/start
 * Initialize or fetch existing verification record
 */
router.post('/harvester/start', async (req: Request, res: Response) => {
  try {
    const { harvesterId } = req.body;
    if (!harvesterId) {
      return res.status(400).json({ success: false, error: 'Harvester ID is required' });
    }
    const verification = await verificationService.getOrCreateVerification(harvesterId);
    res.json({ success: true, verification });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/aadhaar/send-otp
 * Step 1a: Send Aadhaar OTP to linked mobile
 */
router.post('/harvester/aadhaar/send-otp', async (req: Request, res: Response) => {
  try {
    const { harvesterId, aadhaarNumber } = req.body;
    if (!harvesterId || !aadhaarNumber) {
      return res.status(400).json({ success: false, error: 'harvesterId and aadhaarNumber are required' });
    }

    const result = await verificationService.sendAadhaarOtp(harvesterId, aadhaarNumber);
    if (!result.success) {
      return res.status(429).json(result);
    }
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/aadhaar/verify-otp
 * Step 1b: Verify Aadhaar OTP
 */
router.post('/harvester/aadhaar/verify-otp', async (req: Request, res: Response) => {
  try {
    const { harvesterId, aadhaarNumber, otp, transactionId } = req.body;
    if (!harvesterId || (!aadhaarNumber && !transactionId) || !otp) {
      return res.status(400).json({ success: false, error: 'harvesterId, otp, and aadhaarNumber (or transactionId) are required' });
    }

    const verification = await verificationService.verifyAadhaarOtp(harvesterId, aadhaarNumber, otp, transactionId);
    res.json({ success: true, message: 'Aadhaar Verified ✓', verification });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/government-id
 * Step 1: Submit Government ID (Aadhaar / Standard)
 */
router.post('/harvester/government-id', async (req: Request, res: Response) => {
  try {
    const { harvesterId, documentType, documentNumber } = req.body;
    if (!harvesterId || !documentNumber) {
      return res.status(400).json({ success: false, error: 'harvesterId and documentNumber are required' });
    }

    const verification = await verificationService.submitGovernmentId(
      harvesterId,
      documentType,
      documentNumber
    );
    res.json({ success: true, message: 'Government ID submitted and verified.', verification });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/mobile/send-otp
 * Step 2a: Send Mobile OTP
 */
router.post('/harvester/mobile/send-otp', async (req: Request, res: Response) => {
  try {
    const { mobile } = req.body;
    if (!mobile) {
      return res.status(400).json({ success: false, error: 'Mobile number is required' });
    }

    const result = await otpService.sendOtp(mobile);
    if (!result.success) {
      return res.status(429).json(result);
    }
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/mobile/verify-otp
 * Step 2b: Verify Mobile OTP
 */
router.post('/harvester/mobile/verify-otp', async (req: Request, res: Response) => {
  try {
    const { harvesterId, mobile, otp } = req.body;
    if (!harvesterId || !mobile || !otp) {
      return res.status(400).json({ success: false, error: 'harvesterId, mobile, and otp are required' });
    }

    const verification = await verificationService.submitMobileVerification(
      harvesterId,
      mobile,
      otp
    );
    res.json({ success: true, message: 'Mobile verified successfully.', verification });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/registration
 * Step 3: Submit Beekeeper Registration ID
 */
router.post('/harvester/registration', async (req: Request, res: Response) => {
  try {
    const { harvesterId, registrationId, registrationType } = req.body;
    if (!harvesterId || !registrationId) {
      return res.status(400).json({ success: false, error: 'harvesterId and registrationId are required' });
    }

    const verification = await verificationService.submitRegistrationId(
      harvesterId,
      registrationId,
      registrationType
    );
    res.json({ success: true, message: 'Beekeeper Registration verified.', verification });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/location
 * Step 4: Submit Apiary Location
 */
router.post('/harvester/location', async (req: Request, res: Response) => {
  try {
    const { harvesterId, apiaryName, apiaryLocation, apiaryCoordinates } = req.body;
    if (!harvesterId || !apiaryLocation) {
      return res.status(400).json({ success: false, error: 'harvesterId and apiaryLocation are required' });
    }

    const verification = await verificationService.submitApiaryLocation(
      harvesterId,
      apiaryName,
      apiaryLocation,
      apiaryCoordinates
    );
    res.json({ success: true, message: 'Apiary location verified.', verification });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/blockchain-verify
 * Step 5: Final Blockchain Verification Record
 */
router.post('/harvester/blockchain-verify', async (req: Request, res: Response) => {
  try {
    const { harvesterId } = req.body;
    if (!harvesterId) {
      return res.status(400).json({ success: false, error: 'harvesterId is required' });
    }

    const result = await verificationService.submitBlockchainVerification(harvesterId);
    res.json({
      success: true,
      message: 'Harvester successfully verified and recorded on blockchain ledger.',
      ...result
    });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * POST /api/verification/harvester/admin/review
 * Verifier / Admin manual review
 */
router.post('/harvester/admin/review', async (req: Request, res: Response) => {
  try {
    const { harvesterId, field, decision, notes } = req.body;
    if (!harvesterId || !decision) {
      return res.status(400).json({ success: false, error: 'harvesterId and decision (Verified/Rejected) are required' });
    }

    const updated = await verificationService.reviewVerification(
      harvesterId,
      field || 'all',
      decision,
      notes
    );
    res.json({ success: true, verification: updated });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error?.message || String(error) });
  }
});

/**
 * GET /api/verification/verify/harvester/:verificationId
 * GET /api/verify/harvester/:verificationId
 * Public verification endpoint for QR code scanners & certificate lookup
 */
router.get('/verify/harvester/:verificationId', async (req: Request, res: Response) => {
  try {
    const verificationId = String(req.params.verificationId);
    if (!verificationId || verificationId === 'undefined') {
      return res.status(400).json({ success: false, found: false, message: 'Verification ID is required' });
    }

    const result = await verificationService.getPublicVerificationByVerificationId(verificationId);
    if (!result.found) {
      return res.status(404).json({ success: false, ...result });
    }

    res.json({ success: true, ...result });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error?.message || String(error) });
  }
});

export default router;
