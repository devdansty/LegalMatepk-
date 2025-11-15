from qdrant_client import QdrantClient

qdrant_client = QdrantClient(
    url="https://51a42850-e13a-41b9-9d00-103bc99ae2ee.eu-west-2-0.aws.cloud.qdrant.io:6333", 
    api_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0._3afSnrLwBm8Enc64ME6qsbNpgVgeVIgIvzYXscQ4JU",
)

print(qdrant_client.get_collections())