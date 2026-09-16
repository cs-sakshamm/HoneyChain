// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/HoneyChainProvenance.sol";

contract HoneyChainProvenanceTest {
    HoneyChainProvenance provenance;

    function setUp() public {
        provenance = new HoneyChainProvenance();
    }

    function testOwnerIsDeployer() public {
        require(provenance.owner() == address(this), "Owner should be deployer");
    }

    function testRecordEvent() public {
        string memory batchId = "HC-BATCH-2026-TEST01";
        provenance.recordEvent(
            batchId,
            "COLLECTION_RECORDED",
            "HARVESTER-123",
            "0xabcdef1234567890",
            "0x0000000000000000"
        );
        
        HoneyChainProvenance.BatchEvent[] memory events = provenance.getEvents(batchId);
        require(events.length == 1, "Should have 1 event");
        require(keccak256(bytes(events[0].batchId)) == keccak256(bytes(batchId)), "BatchId mismatch");
        require(keccak256(bytes(events[0].eventType)) == keccak256(bytes("COLLECTION_RECORDED")), "EventType mismatch");
        require(keccak256(bytes(events[0].actorId)) == keccak256(bytes("HARVESTER-123")), "ActorId mismatch");
        require(keccak256(bytes(events[0].dataHash)) == keccak256(bytes("0xabcdef1234567890")), "DataHash mismatch");
    }

    function testMultiStepProvenanceTimeline() public {
        string memory batchId = "HC-BATCH-2026-FULL01";
        provenance.recordEvent(batchId, "HARVEST_REGISTERED", "harvester-1", "0xhash1", "GENESIS");
        provenance.recordEvent(batchId, "PROCESSING_COMPLETED", "collector-1", "0xhash2", "0xhash1");
        provenance.recordEvent(batchId, "LAB_CERTIFICATION_APPROVED", "lab-1", "0xhash3", "0xhash2");
        provenance.recordEvent(batchId, "PACKAGING_AND_FINAL_SEALED", "packager-1", "0xhash4", "0xhash3");

        HoneyChainProvenance.BatchEvent[] memory events = provenance.getEvents(batchId);
        require(events.length == 4, "Should have 4 timeline events");
        require(keccak256(bytes(events[0].eventType)) == keccak256(bytes("HARVEST_REGISTERED")), "Step 1 mismatch");
        require(keccak256(bytes(events[1].eventType)) == keccak256(bytes("PROCESSING_COMPLETED")), "Step 2 mismatch");
        require(keccak256(bytes(events[2].eventType)) == keccak256(bytes("LAB_CERTIFICATION_APPROVED")), "Step 3 mismatch");
        require(keccak256(bytes(events[3].eventType)) == keccak256(bytes("PACKAGING_AND_FINAL_SEALED")), "Step 4 mismatch");
    }

    function testHarvesterVerification() public {
        string memory verificationId = "HV-2026-TEST001";
        provenance.recordHarvesterVerification(
            verificationId,
            "USR-HARVESTER-001",
            "0xhash999",
            "VERIFIED"
        );

        require(provenance.isHarvesterVerified(verificationId), "Harvester should be verified");
        HoneyChainProvenance.HarvesterVerificationRecord memory record = provenance.getHarvesterVerification(verificationId);
        require(keccak256(bytes(record.status)) == keccak256(bytes("VERIFIED")), "Status mismatch");
        require(keccak256(bytes(record.harvesterId)) == keccak256(bytes("USR-HARVESTER-001")), "Harvester ID mismatch");
    }
}
