from io import BytesIO
import json
import logging
from confluent_kafka import Consumer, KafkaError, KafkaException
from datetime import datetime
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from azure.storage.blob import BlobServiceClient
import uuid

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

# Configuration constants
BOOTSTRAP_SERVERS = "kafka.dev.bsmch.net:443"
CHECKIN_TOPIC = "flight-checkin-topic"
UPDATES_TOPIC = "flight-updates-topic"
GROUP_ID = "ingest-group-sunhouse"

# In-memory data store for batching separated by topic
topic_buffers = {
    CHECKIN_TOPIC: [],
    UPDATES_TOPIC: []
}

BATCH_SIZE = 2000  # Adjust based on your volume preferences

SAS_TOKEN = "sp=racwdlm&st=2026-06-11T16:33:07Z&se=2026-07-03T00:48:07Z&spr=https&sv=2026-02-06&sr=c&sig=O%2FK3ofXjlcbOk40q8aZJYDg6ZcLihZhAbmub%2Bwf55N0%3D"
ACCOUNT_URL = f"https://dataengineering2025sa.blob.core.windows.net"

blob_service_client = BlobServiceClient(
    account_url=ACCOUNT_URL,
    credential=SAS_TOKEN
)

container_client = blob_service_client.get_container_client(
    "warehouse"
) 

def flush_topic_to_parquet(topic_name):
    """Flushes the buffered data for a specific topic to its own Azure folder."""
    buffer = topic_buffers.get(topic_name, [])

    if not buffer:
        return

    try:
        now = datetime.utcnow()
        df = pd.DataFrame(buffer)

        table = pa.Table.from_pandas(
            df,
            preserve_index=False
        )

        parquet_buffer = BytesIO()

        pq.write_table(
            table,
            parquet_buffer,
            compression="snappy"
        )

        unique_id = uuid.uuid4().hex[:8]

        # Dynamic routing to separate topic folders inside bronze
        blob_path = (
            f"SunHouse/Bronze/{topic_name}/"
            f"batch_{int(now.timestamp())}_{unique_id}.parquet"
        )

        container_client.upload_blob(
            name=blob_path,
            data=parquet_buffer.getvalue(),
            overwrite=False
        )

        logging.info(
            "Uploaded %s parquet batch with %d rows to %s",
            topic_name, len(buffer), blob_path
        )

        # Clear only this topic's buffer after successful upload
        buffer.clear()

    except Exception as e:
        logging.exception(
            "Failed uploading parquet batch for topic %s: %s",
            topic_name, e
        )    

def process_flight_message(raw_value, topic_name):
    """Parses JSON payload and appends it to the correct topic buffer."""
    if topic_name not in topic_buffers:
        logging.warning("Received message from untracked topic: %s", topic_name)
        return

    try:
        flight_data = json.loads(raw_value)
        
        if isinstance(flight_data, dict):
            # Inject metadata tracking ingest time
            flight_data["ingestion_timestamp"] = str(datetime.utcnow())
            
            topic_buffers[topic_name].append(flight_data)
        else:
            logging.warning("Skipped message from %s: Payload is not a JSON object", topic_name)

        # Flush only if this specific topic's buffer hits the batch size
        if len(topic_buffers[topic_name]) >= BATCH_SIZE:
            flush_topic_to_parquet(topic_name)

    except Exception as e:
        logging.error(
            "Failed to parse flight message from topic %s: %s",
            topic_name, e
        )

def main():
    conf = {
        "bootstrap.servers": BOOTSTRAP_SERVERS,
        "group.id": GROUP_ID,
        "auto.offset.reset": "earliest",
        "security.protocol": "SSL",
        "enable.ssl.certificate.verification": False
    }

    consumer = Consumer(conf)

    # Subscribe to both flight topics
    consumer.subscribe([CHECKIN_TOPIC, UPDATES_TOPIC])
    logging.info("Consumer successfully subscribed to %s and %s", CHECKIN_TOPIC, UPDATES_TOPIC)

    try:
        while True:
            msg = consumer.poll(timeout=1.0)
            
            if msg is None:
                continue
            
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                else:
                    raise KafkaException(msg.error())

            topic = msg.topic()
            payload = msg.value().decode('utf-8')

            process_flight_message(payload, topic)

    except KeyboardInterrupt:
        logging.info("Shutting down consumer gracefully...")
    finally:
        consumer.close()
        # Flush any remaining messages left in either buffer on shutdown
        for topic in topic_buffers.keys():
            flush_topic_to_parquet(topic)

if __name__ == "__main__":
    main()