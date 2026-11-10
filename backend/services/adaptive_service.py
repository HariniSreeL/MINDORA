# Mindora Backend - Rule-based Adaptive Difficulty Engine
# Speed is never used as the sole performance signal.
# Scikit-learn Decision Tree integration is reserved until genuine session data exists.

from database.db import Database

db = Database()

GAME_NAMES = {
    'memory_match': 'Memory Match',
    'pattern_match': 'Pattern Match',
    'word_recall': 'Word Recall',
    'sound_recognition': 'Sound Recognition',
}

SUPPORTIVE_MESSAGES = {
    'encourage': 'Wonderful effort today. Take your time and enjoy each moment at your own pace.',
    'steady': 'Very nice and steady focus. You are doing wonderfully well.',
    'advance': 'Beautiful work. You may try the next gentle level whenever you wish.',
}


class AdaptiveDifficultyEngine:
    """Rule-based engine with a stable interface for a future sklearn model."""

    def evaluate_performance(self, accuracy_ratio=0.0, duration_seconds=0.0, mistakes=0,
                             hints_used=0, level=1, relaxed_mode=False, completed=True):
        """Compatibility wrapper. Duration is recorded but not used as the primary signal."""
        _ = duration_seconds, relaxed_mode
        return self.evaluate_session(accuracy_ratio, mistakes, hints_used, completed, level)

    def evaluate_session(self, accuracy_ratio, mistakes, hints_used, completed, level=1):
        """Evaluate a single session without using duration as the primary signal."""
        accuracy = float(accuracy_ratio or 0.0)
        mistakes = int(mistakes or 0)
        hints_used = int(hints_used or 0)
        completed = bool(completed)

        if (not completed) or accuracy < 0.45 or mistakes >= 5 or hints_used >= 4:
            band = 'encourage'
        elif accuracy >= 0.85 and mistakes <= 1 and hints_used <= 1 and completed:
            band = 'advance'
        else:
            band = 'steady'

        if band == 'advance':
            recommended_level = min(int(level) + 1, 4)
        elif band == 'encourage':
            recommended_level = max(int(level), 1)
        else:
            recommended_level = int(level)

        return {
            'band': band,
            'engine': 'rule_based',
            'ml_trained': False,
            'recommended_level': recommended_level,
            'feature_signals': {
                'accuracy': round(accuracy, 3),
                'mistakes': mistakes,
                'hints_used': hints_used,
                'completed': completed,
                'level': int(level),
            },
            'supportive_message': SUPPORTIVE_MESSAGES[band],
        }

    def evaluate_recent_history(self, user_id, game_id, current_level=1):
        """Look at recent sessions for consistency, repeated mistakes, and hints."""
        sessions = db.query(
            """
            SELECT correct_matches, mistakes, hints_used, total_attempts, completed, level
            FROM game_sessions
            WHERE user_id = ? AND game_id = ? AND status IN ('completed', 'interrupted')
            ORDER BY created_at DESC
            LIMIT 5
            """,
            (user_id, game_id),
        )
        if not sessions:
            return self.evaluate_session(0.7, 0, 0, True, current_level)

        accuracies = []
        mistakes_total = 0
        hints_total = 0
        completed_count = 0
        for row in sessions:
            attempts = row['total_attempts'] or (row['correct_matches'] + row['mistakes'])
            accuracy = (row['correct_matches'] / attempts) if attempts else 0.0
            accuracies.append(accuracy)
            mistakes_total += row['mistakes'] or 0
            hints_total += row['hints_used'] or 0
            if row['completed']:
                completed_count += 1

        avg_accuracy = sum(accuracies) / len(accuracies)
        latest = sessions[0]
        latest_attempts = latest['total_attempts'] or (latest['correct_matches'] + latest['mistakes'])
        latest_accuracy = (latest['correct_matches'] / latest_attempts) if latest_attempts else 0.0

        consecutive_struggles = 0
        consecutive_successes = 0
        for row in sessions:
            attempts = row['total_attempts'] or (row['correct_matches'] + row['mistakes'])
            accuracy = (row['correct_matches'] / attempts) if attempts else 0.0
            struggling = (not row['completed']) or accuracy < 0.5 or (row['mistakes'] or 0) >= 4
            if struggling:
                if consecutive_successes == 0:
                    consecutive_struggles += 1
                else:
                    break
            else:
                if consecutive_struggles == 0:
                    consecutive_successes += 1
                else:
                    break

        if consecutive_struggles >= 2 or avg_accuracy < 0.45:
            band = 'encourage'
            recommended_level = max(int(current_level), 1)
        elif consecutive_successes >= 2 and avg_accuracy >= 0.85 and hints_total <= 2:
            band = 'advance'
            recommended_level = min(int(current_level) + 1, 4)
        else:
            band = 'steady'
            recommended_level = int(current_level)

        return {
            'band': band,
            'engine': 'rule_based',
            'ml_trained': False,
            'recommended_level': recommended_level,
            'consecutive_successes': consecutive_successes,
            'consecutive_struggles': consecutive_struggles,
            'feature_signals': {
                'recent_accuracy': round(avg_accuracy, 3),
                'latest_accuracy': round(latest_accuracy, 3),
                'mistakes': mistakes_total,
                'hints_used': hints_total,
                'completed_recent': completed_count,
                'sessions_considered': len(sessions),
                'level': int(current_level),
            },
            'supportive_message': SUPPORTIVE_MESSAGES[band],
        }

    def persist_state(self, user_id, game_id, evaluation):
        db.execute(
            """
            INSERT INTO adaptive_difficulty_states (
                user_id, game_id, current_band, recommended_level,
                accuracy_ratio, consecutive_successes, consecutive_struggles, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, game_id) DO UPDATE SET
                current_band = excluded.current_band,
                recommended_level = excluded.recommended_level,
                accuracy_ratio = excluded.accuracy_ratio,
                consecutive_successes = excluded.consecutive_successes,
                consecutive_struggles = excluded.consecutive_struggles,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                user_id,
                game_id,
                evaluation['band'],
                evaluation['recommended_level'],
                evaluation.get('feature_signals', {}).get('recent_accuracy')
                or evaluation.get('feature_signals', {}).get('accuracy')
                or 0.0,
                evaluation.get('consecutive_successes', 0),
                evaluation.get('consecutive_struggles', 0),
            ),
        )


adaptive_engine = AdaptiveDifficultyEngine()
