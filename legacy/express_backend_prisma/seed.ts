import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting HoneyChain database seed with verified multi-role supply chain partners...');

  const now = new Date();

  // ── 1. Default Harvester User & Harvester Verification (3/3) ──
  const harvesterUser = await prisma.user.upsert({
    where: { email_role: { email: 'operations@honeychain.io', role: 'HARVESTER' } },
    update: {
      name: 'HoneyChain Apiary Manager',
      phone: '+919876543210',
      role: 'HARVESTER',
      beekeeperId: 'HC-BK-97FD3395',
      facilityLocation: 'Cascade Valley, OR (44.0521, -121.3153)'
    },
    create: {
      id: 'user-default-harvester',
      name: 'HoneyChain Apiary Manager',
      email: 'operations@honeychain.io',
      phone: '+919876543210',
      role: 'HARVESTER',
      beekeeperId: 'HC-BK-97FD3395',
      facilityLocation: 'Cascade Valley, OR (44.0521, -121.3153)'
    }
  });

  await prisma.harvesterVerification.upsert({
    where: { harvesterId: harvesterUser.id },
    update: {
      governmentIdVerified: 'Not Started',
      mobileVerified: 'Not Started',
      registrationVerified: 'Not Started',
      locationVerified: 'Not Started',
      verificationStatus: 'Not Started',
      verificationId: null,
      verificationHash: null,
      transactionHash: null,
      blockNumber: null,
      verifiedAt: null
    },
    create: {
      harvesterId: harvesterUser.id,
      governmentIdVerified: 'Not Started',
      mobileVerified: 'Not Started',
      registrationVerified: 'Not Started',
      locationVerified: 'Not Started',
      verificationStatus: 'Not Started',
      apiaryName: 'Apiary 1',
      apiaryLocation: 'Cascade Valley, OR',
      apiaryCoordinates: '44.0521, -121.3153'
    }
  });
  console.log(`✓ Seeded Harvester User (Unverified / Ready for Verification)`);

  // ── 2. Seed Verified Collection & Processing Centres (with Real Coordinates) ──
  const collectorsData = [
    {
      id: 'user-collector-bend',
      email: 'processor@honeychain.io',
      name: 'Cascade Honey Collection & Cold Extraction Hub',
      phone: '+919876510001',
      role: 'COLLECTOR_PROCESSOR',
      organizationName: 'Cascade Honey Processing Ltd.',
      facilityLocation: 'Bend Industrial Center, OR (44.0582, -121.3153)',
      licenseNumber: 'FSSAI-PROC-2026-9812',
      designation: 'Managing Director'
    },
    {
      id: 'user-collector-redmond',
      email: 'redmond.collector@honeychain.io',
      name: 'High Desert Honey Cooperative Center',
      phone: '+919876510002',
      role: 'COLLECTOR_PROCESSOR',
      organizationName: 'High Desert Honey Cooperative',
      facilityLocation: 'Redmond Agri Hub, OR (44.2726, -121.1739)',
      licenseNumber: 'FSSAI-PROC-2026-4410',
      designation: 'Chief Extraction Officer'
    },
    {
      id: 'user-collector-eugene',
      email: 'eugene.collector@honeychain.io',
      name: 'Willamette Valley Apiculture Processing Center',
      phone: '+919876510003',
      role: 'COLLECTOR_PROCESSOR',
      organizationName: 'Willamette Honey Co.',
      facilityLocation: 'Eugene South Valley Center, OR (44.0521, -123.0868)',
      licenseNumber: 'FSSAI-PROC-2026-7789',
      designation: 'Plant Operations Head'
    }
  ];

  for (const c of collectorsData) {
    const u = await prisma.user.upsert({
      where: { email_role: { email: c.email, role: c.role } },
      update: c,
      create: c
    });

    await prisma.collectorVerification.upsert({
      where: { collectorId: u.id },
      update: {
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        organizationName: u.organizationName,
        facilityLocation: u.facilityLocation,
        businessVerified: 'Verified',
        licenseNumber: u.licenseNumber,
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
        verifiedAt: now
      },
      create: {
        collectorId: u.id,
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        mobileVerifiedAt: now,
        organizationName: u.organizationName,
        facilityLocation: u.facilityLocation,
        businessDetails: 'Industrial Grade Honey Centrifuge & Triple Filtration ISO 22000 Facility',
        businessVerified: 'Verified',
        businessVerifiedAt: now,
        governmentIdType: 'FSSAI_LICENSE',
        governmentIdReference: `FSSAI-${c.licenseNumber}`,
        licenseNumber: u.licenseNumber,
        kycProvider: 'DIGIO',
        kycStatus: 'Verified',
        kycVerifiedAt: now,
        verificationStatus: 'Verified',
        verifiedAt: now
      }
    });
  }
  console.log(`✓ Seeded ${collectorsData.length} Verified Collection & Processing Centres`);

  // ── 3. Seed Verified Laboratory Testing Centres (with Real Coordinates) ──
  const labsData = [
    {
      id: 'user-lab-corvallis',
      email: 'lab@honeychain.io',
      name: 'Pacific Pure Apiculture Analytical Labs',
      phone: '+919876520001',
      role: 'LAB',
      organizationName: 'Pacific Pure Apiculture Labs LLC',
      facilityLocation: 'Corvallis Tech Campus, OR (44.5646, -123.2620)',
      licenseNumber: 'NABL-LAB-2026-4402',
      designation: 'Chief Analytical Chemist'
    },
    {
      id: 'user-lab-salem',
      email: 'salem.lab@honeychain.io',
      name: 'Cascade Food Safety & Spectrometry Testing Lab',
      phone: '+919876520002',
      role: 'LAB',
      organizationName: 'Cascade Quality Analytical Services',
      facilityLocation: 'Salem Bio-Park, OR (44.9429, -123.0351)',
      licenseNumber: 'NABL-LAB-2026-6681',
      designation: 'Senior Chemist & Food Auditor'
    },
    {
      id: 'user-lab-portland',
      email: 'portland.lab@honeychain.io',
      name: 'Columbia Bio-Testing & Pollen Analysis Lab',
      phone: '+919876520003',
      role: 'LAB',
      organizationName: 'Columbia Apiculture Diagnostics',
      facilityLocation: 'Portland Pearl District Lab Hub, OR (45.5152, -122.6784)',
      licenseNumber: 'ISO-17025-LAB-2026-8801',
      designation: 'Lead Microbiologist'
    }
  ];

  for (const l of labsData) {
    const u = await prisma.user.upsert({
      where: { email_role: { email: l.email, role: l.role } },
      update: l,
      create: l
    });

    await prisma.labVerification.upsert({
      where: { labId: u.id },
      update: {
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        labName: u.name,
        labAddress: u.facilityLocation,
        labRegistrationNumber: u.licenseNumber,
        accreditation: 'NABL / ISO/IEC 17025 Certified',
        labDetailsVerified: 'Verified',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
        verifiedAt: now
      },
      create: {
        labId: u.id,
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        mobileVerifiedAt: now,
        labName: u.name,
        labAddress: u.facilityLocation,
        labRegistrationNumber: u.licenseNumber,
        accreditation: 'NABL / ISO/IEC 17025 Certified for Physicochemical & Spectrometric Honey Testing',
        labDetailsVerified: 'Verified',
        labDetailsVerifiedAt: now,
        governmentIdType: 'DRIVERS_LICENSE',
        governmentIdReference: `DOC-LAB-${u.id.slice(-6).toUpperCase()}`,
        qualification: 'M.Sc Analytical Chemistry & Certified Lead Food Auditor',
        authorizedTestingDetails: 'Moisture (Refractometry), HMF (HPLC-UV), Diastase (Schade), F/G Purity (GC-FID), Pollen (Microscopy), Antibiotic Residues (LC-MS/MS)',
        kycProvider: 'SIGNZY',
        kycStatus: 'Verified',
        kycVerifiedAt: now,
        verificationStatus: 'Verified',
        verifiedAt: now
      }
    });
  }
  console.log(`✓ Seeded ${labsData.length} Verified Laboratory Testing Centres`);

  // ── 4. Seed Verified Packaging & Bottling Centres (with Real Coordinates) ──
  const packagersData = [
    {
      id: 'user-packager-portland',
      email: 'packaging@honeychain.io',
      name: 'Artisan Honey Bottling & Cleanroom Packaging Co.',
      phone: '+919876530001',
      role: 'PACKAGING',
      organizationName: 'Artisan Honey Packaging Co.',
      facilityLocation: 'Portland Logistics Hub, OR (45.5231, -122.6765)',
      licenseNumber: 'FSSAI-PKG-2026-1184',
      designation: 'Packaging Operations Lead'
    },
    {
      id: 'user-packager-tigard',
      email: 'tigard.packaging@honeychain.io',
      name: 'Pacific Seal & Tamper-Evident Packaging Center',
      phone: '+919876530002',
      role: 'PACKAGING',
      organizationName: 'Pacific Seal Tech LLC',
      facilityLocation: 'Tigard Packaging Facility, OR (45.4312, -122.7712)',
      licenseNumber: 'FSSAI-PKG-2026-5590',
      designation: 'Plant Supervisor'
    }
  ];

  for (const p of packagersData) {
    const u = await prisma.user.upsert({
      where: { email_role: { email: p.email, role: p.role } },
      update: p,
      create: p
    });

    await prisma.packagingVerification.upsert({
      where: { packagerId: u.id },
      update: {
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        organizationName: u.organizationName,
        facilityLocation: u.facilityLocation,
        packagingLicenseNumber: u.licenseNumber,
        facilityDetailsVerified: 'Verified',
        kycStatus: 'Verified',
        verificationStatus: 'Verified',
        verifiedAt: now
      },
      create: {
        packagerId: u.id,
        fullName: u.name,
        mobileNumber: u.phone,
        mobileVerified: 'Verified',
        mobileVerifiedAt: now,
        organizationName: u.organizationName,
        facilityLocation: u.facilityLocation,
        packagingLicenseNumber: u.licenseNumber,
        facilityDetailsVerified: 'Verified',
        facilityDetailsVerifiedAt: now,
        governmentIdType: 'FSSAI_LICENSE',
        governmentIdReference: `PKG-LIC-${p.licenseNumber}`,
        authorizedPackagingDetails: 'Automated Sterile Bottling, Nitrogen Flushing, Tamper-Evident Induction Sealing, High-Resolution QR Labeling',
        kycProvider: 'DIGIO',
        kycStatus: 'Verified',
        kycVerifiedAt: now,
        verificationStatus: 'Verified',
        verifiedAt: now
      }
    });
  }
  console.log(`✓ Seeded ${packagersData.length} Verified Packaging Centres`);

  console.log('✅ PostgreSQL database seeding completed with verified partner network!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
