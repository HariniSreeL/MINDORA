# Compatibility wrapper. Adaptive difficulty is rule-based until genuine data exists.
from services.adaptive_service import adaptive_engine, AdaptiveDifficultyEngine

ml_service = adaptive_engine
AdaptiveDifficultyMLService = AdaptiveDifficultyEngine
