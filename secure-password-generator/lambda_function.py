import json
import secrets
import string

def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    length     = int(params.get("length", 16))
    use_upper  = params.get("upper", "true") == "true"
    use_lower  = params.get("lower", "true") == "true"
    use_digits = params.get("digits", "true") == "true"
    use_symbols= params.get("symbols", "true") == "true"

    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if http_method == "GET" and not params.get("generate"):
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "text/html"},
            "body": get_html()
        }

    charset = ""
    if use_upper:   charset += string.ascii_uppercase
    if use_lower:   charset += string.ascii_lowercase
    if use_digits:  charset += string.digits
    if use_symbols: charset += "!@#$%^&*()_+-=[]{}|;:,.<>?"

    if not charset:
        charset = string.ascii_letters + string.digits

    length = max(8, min(64, length))
    password = ''.join(secrets.choice(charset) for _ in range(length))
    strength, color = calculate_strength(password)

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({
            "password": password,
            "strength": strength,
            "color": color,
            "length": len(password)
        })
    }


def calculate_strength(password):
    score = 0
    if len(password) >= 12: score += 1
    if len(password) >= 16: score += 1
    if any(c.isupper() for c in password): score += 1
    if any(c.islower() for c in password): score += 1
    if any(c.isdigit() for c in password): score += 1
    if any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password): score += 1

    if score <= 2:   return "Weak",   "#ef4444"
    elif score <= 4: return "Medium", "#f59e0b"
    else:            return "Strong", "#10b981"


def get_html():
    return open("index.html").read() if __import__("os").path.exists("index.html") else "<h1>Password Generator</h1>"
