"""
Lightweight embedded MQTT 3.1.1 Broker for local development & testing.
Runs on localhost:1883 without requiring external Mosquitto installation.
"""
from __future__ import annotations

import asyncio
import logging
import socket
from typing import Dict, Set

logging.basicConfig(level=logging.INFO, format="[MQTT-Broker] %(asctime)s - %(message)s")
logger = logging.getLogger("LocalBroker")


class LocalMQTTBroker:
    def __init__(self, host: str = "0.0.0.0", port: int = 1883):
        self.host = host
        self.port = port
        self.subscriptions: Dict[str, Set[asyncio.StreamWriter]] = {}
        self.clients: Set[asyncio.StreamWriter] = set()

    async def start(self):
        server = await asyncio.start_server(self.handle_client, self.host, self.port)
        logger.info(f"HoneyChain Embedded MQTT Broker running on {self.host}:{self.port}")
        async with server:
            await server.serve_forever()

    def _matches_topic(self, sub_filter: str, topic: str) -> bool:
        if sub_filter == topic or sub_filter == "#":
            return True
        sub_parts = sub_filter.split("/")
        topic_parts = topic.split("/")
        for i, part in enumerate(sub_parts):
            if part == "#":
                return True
            if part == "+":
                continue
            if i >= len(topic_parts) or part != topic_parts[i]:
                return False
        return len(sub_parts) == len(topic_parts)

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        peer = writer.get_extra_info("peername")
        self.clients.add(writer)
        subscribed_topics: Set[str] = set()

        try:
            while True:
                header = await reader.read(1)
                if not header:
                    break
                packet_type = header[0] >> 4

                # Read remaining length
                multiplier = 1
                length = 0
                while True:
                    b = await reader.read(1)
                    if not b:
                        break
                    digit = b[0]
                    length += (digit & 127) * multiplier
                    multiplier *= 128
                    if (digit & 128) == 0:
                        break

                body = await reader.readexactly(length) if length > 0 else b""

                if packet_type == 1:  # CONNECT
                    # Reply CONNACK (0x20, 0x02, 0x00, 0x00) -> Connection Accepted
                    writer.write(bytes([0x20, 0x02, 0x00, 0x00]))
                    await writer.drain()

                elif packet_type == 3:  # PUBLISH
                    flags = header[0] & 0x0F
                    qos = (flags >> 1) & 0x03
                    # Topic length
                    topic_len = (body[0] << 8) | body[1]
                    topic = body[2 : 2 + topic_len].decode("utf-8", errors="ignore")
                    offset = 2 + topic_len

                    packet_id = None
                    if qos > 0:
                        packet_id = (body[offset] << 8) | body[offset + 1]
                        offset += 2

                    payload = body[offset:]
                    # If QoS 1, reply PUBACK (0x40, 0x02, id_msb, id_lsb)
                    if qos == 1 and packet_id is not None:
                        puback = bytes([0x40, 0x02, (packet_id >> 8) & 0xFF, packet_id & 0xFF])
                        writer.write(puback)
                        await writer.drain()

                    # Broadcast to matching subscribers
                    for sub_filter, subscribers in self.subscriptions.items():
                        if self._matches_topic(sub_filter, topic):
                            # Re-encode publish packet for subscriber (QoS 0)
                            topic_bytes = topic.encode("utf-8")
                            pub_len = 2 + len(topic_bytes) + len(payload)
                            
                            # Encode remaining length
                            rem_bytes = bytearray()
                            rem = pub_len
                            while True:
                                d = rem % 128
                                rem = rem // 128
                                if rem > 0:
                                    d |= 0x80
                                rem_bytes.append(d)
                                if rem <= 0:
                                    break

                            fwd_packet = bytes([0x30]) + bytes(rem_bytes) + bytes([len(topic_bytes) >> 8, len(topic_bytes) & 0xFF]) + topic_bytes + payload
                            for sub_writer in list(subscribers):
                                try:
                                    sub_writer.write(fwd_packet)
                                    await sub_writer.drain()
                                except Exception:
                                    subscribers.discard(sub_writer)

                elif packet_type == 8:  # SUBSCRIBE
                    packet_id_msb = body[0]
                    packet_id_lsb = body[1]
                    offset = 2
                    granted_qos = []
                    while offset < len(body):
                        filter_len = (body[offset] << 8) | body[offset + 1]
                        offset += 2
                        sub_filter = body[offset : offset + filter_len].decode("utf-8", errors="ignore")
                        offset += filter_len
                        requested_qos = body[offset]
                        offset += 1
                        granted_qos.append(requested_qos)
                        if sub_filter not in self.subscriptions:
                            self.subscriptions[sub_filter] = set()
                        self.subscriptions[sub_filter].add(writer)
                        subscribed_topics.add(sub_filter)

                    # SUBACK (0x90)
                    suback = bytes([0x90, 2 + len(granted_qos), packet_id_msb, packet_id_lsb]) + bytes(granted_qos)
                    writer.write(suback)
                    await writer.drain()

                elif packet_type == 12:  # PINGREQ
                    # PINGRESP (0xD0, 0x00)
                    writer.write(bytes([0xD0, 0x00]))
                    await writer.drain()

                elif packet_type == 14:  # DISCONNECT
                    break

        except Exception as err:
            logger.debug(f"Client {peer} disconnected with {err}")
        finally:
            self.clients.discard(writer)
            for topic in subscribed_topics:
                if topic in self.subscriptions:
                    self.subscriptions[topic].discard(writer)
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass


if __name__ == "__main__":
    broker = LocalMQTTBroker()
    try:
        asyncio.run(broker.start())
    except KeyboardInterrupt:
        logger.info("Broker stopped.")
