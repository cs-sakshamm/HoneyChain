// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HoneyChainProvenance {
    address public owner;

    struct BatchEvent {
        string batchId;
        string eventType;
        string actorId;
        string dataHash;
        string previousEventHash;
        uint256 timestamp;
    }

    struct HarvesterVerificationRecord {
        string verificationId;
        string harvesterId;
        string recordHash;
        string status;
        uint256 timestamp;
    }

    mapping(string => BatchEvent[]) public batchEvents;
    mapping(string => HarvesterVerificationRecord) public harvesterVerifications;
    string[] public verificationIds;

    event ProvenanceRecorded(
        string indexed batchId,
        string eventType,
        string actorId,
        string dataHash,
        string previousEventHash,
        uint256 timestamp
    );

    event HarvesterVerified(
        string indexed verificationId,
        string indexed harvesterId,
        string recordHash,
        string status,
        uint256 timestamp
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can record events");
        _;
    }

    function recordEvent(
        string memory batchId,
        string memory eventType,
        string memory actorId,
        string memory dataHash,
        string memory previousEventHash
    ) public onlyOwner {
        BatchEvent memory newEvent = BatchEvent({
            batchId: batchId,
            eventType: eventType,
            actorId: actorId,
            dataHash: dataHash,
            previousEventHash: previousEventHash,
            timestamp: block.timestamp
        });

        batchEvents[batchId].push(newEvent);

        emit ProvenanceRecorded(
            batchId,
            eventType,
            actorId,
            dataHash,
            previousEventHash,
            block.timestamp
        );
    }

    function getEvents(string memory batchId) public view returns (BatchEvent[] memory) {
        return batchEvents[batchId];
    }

    function recordHarvesterVerification(
        string memory verificationId,
        string memory harvesterId,
        string memory recordHash,
        string memory status
    ) public onlyOwner {
        require(bytes(verificationId).length > 0, "Verification ID cannot be empty");
        require(bytes(recordHash).length > 0, "Record hash cannot be empty");

        HarvesterVerificationRecord memory record = HarvesterVerificationRecord({
            verificationId: verificationId,
            harvesterId: harvesterId,
            recordHash: recordHash,
            status: status,
            timestamp: block.timestamp
        });

        if (bytes(harvesterVerifications[verificationId].verificationId).length == 0) {
            verificationIds.push(verificationId);
        }

        harvesterVerifications[verificationId] = record;

        emit HarvesterVerified(
            verificationId,
            harvesterId,
            recordHash,
            status,
            block.timestamp
        );
    }

    function getHarvesterVerification(string memory verificationId) public view returns (HarvesterVerificationRecord memory) {
        return harvesterVerifications[verificationId];
    }

    function isHarvesterVerified(string memory verificationId) public view returns (bool) {
        return bytes(harvesterVerifications[verificationId].verificationId).length > 0;
    }
}
