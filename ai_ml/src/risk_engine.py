from __future__ import annotations


TEMPERATURE_MIN = 30.0
TEMPERATURE_MAX = 36.0

HUMIDITY_MIN = 50.0
HUMIDITY_MAX = 70.0


class RiskEngine:

    def analyze(
        self,
        sensors: dict,
        ml_result: dict,
        features: dict,
    ) -> dict:

        temperature = float(sensors["temperature_c"])
        humidity = float(sensors["humidity_pct"])
        weight = float(sensors["weight_kg"])
        acoustics = float(sensors["acoustics_hz"])

        anomaly_detected = ml_result["anomaly_detected"]

        reasons = []
        alerts = []

        # ---------------------------------------------------------
        # Temperature
        # ---------------------------------------------------------

        if temperature < TEMPERATURE_MIN:
            temperature_status = "LOW"

            reasons.append(
                "temperature below current reference range"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "TEMPERATURE",
                "message": (
                    "Hive temperature is below the current "
                    "reference range."
                ),
            })

        elif temperature > TEMPERATURE_MAX:
            temperature_status = "HIGH"

            reasons.append(
                "temperature above current reference range"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "TEMPERATURE",
                "message": (
                    "Hive temperature is above the current "
                    "reference range."
                ),
            })

        else:
            temperature_status = "NORMAL"

        # ---------------------------------------------------------
        # Humidity
        # ---------------------------------------------------------

        if humidity < HUMIDITY_MIN:
            humidity_status = "LOW"

            reasons.append(
                "humidity below current reference range"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "HUMIDITY",
                "message": (
                    "Hive humidity is below the current "
                    "reference range."
                ),
            })

        elif humidity > HUMIDITY_MAX:
            humidity_status = "HIGH"

            reasons.append(
                "humidity above current reference range"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "HUMIDITY",
                "message": (
                    "Hive humidity is above the current "
                    "reference range."
                ),
            })

        else:
            humidity_status = "NORMAL"

        # ---------------------------------------------------------
        # Weight trend
        # ---------------------------------------------------------

        weight_delta_1h = features["weight_kg_delta_1h"]
        weight_delta_24h = features["weight_delta_24h"]

        if weight_delta_24h < -0.25:
            weight_status = "DECLINING"
            weight_trend = "DECREASING"

            reasons.append(
                "significant 24-hour weight decline"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "WEIGHT",
                "message": (
                    "Hive weight has shown a significant "
                    "decline over the last 24 hours."
                ),
            })

        elif weight_delta_24h > 0.25:
            weight_status = "INCREASING"
            weight_trend = "INCREASING"

        elif abs(weight_delta_1h) > 0.10:
            weight_status = "CHANGING"
            weight_trend = "CHANGING"

        else:
            weight_status = "STABLE"
            weight_trend = "STABLE"

        # ---------------------------------------------------------
        # Machine-learning anomaly
        # ---------------------------------------------------------

        if anomaly_detected:

            reasons.append(
                "multivariate ML anomaly detected"
            )

            alerts.append({
                "severity": "MEDIUM",
                "type": "ANOMALY",
                "message": (
                    "Multivariate hive telemetry shows an "
                    "unusual pattern."
                ),
            })

        # ---------------------------------------------------------
        # Overall risk
        # ---------------------------------------------------------

        high_conditions = 0

        if temperature_status != "NORMAL":
            high_conditions += 1

        if humidity_status != "NORMAL":
            high_conditions += 1

        if weight_status == "DECLINING":
            high_conditions += 1

        if anomaly_detected:
            high_conditions += 1

        if high_conditions == 0:
            risk_level = "LOW"
            status = "HEALTHY"

        elif high_conditions == 1:
            risk_level = "MEDIUM"
            status = "ATTENTION"

        else:
            risk_level = "HIGH"
            status = "ALERT"

        return {
            "risk_level": risk_level,
            "status": status,
            "temperature_status": temperature_status,
            "humidity_status": humidity_status,
            "weight_status": weight_status,
            "weight_trend": weight_trend,
            "acoustics_status": (
                "UNUSUAL" if anomaly_detected else "NORMAL"
            ),
            "reasons": reasons,
            "alerts": alerts,
        }