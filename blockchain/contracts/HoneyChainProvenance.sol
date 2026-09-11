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

    mapping(string => BatchEvent[]) public batchEvents;

    event ProvenanceRecorded(
        string indexed batchId,
        string eventType,
        string actorId,
        string dataHash,
        string previousEventHash,
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
}
