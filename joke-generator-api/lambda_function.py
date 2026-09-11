import json
import random

def lambda_handler(event, context):
    jokes = [
        {"joke": "Why do programmers prefer dark mode? Because light attracts bugs!"},
        {"joke": "Why did the developer go broke? Because he used up all his cache!"},
        {"joke": "What do you call a bear with no teeth? A gummy bear!"},
        {"joke": "Why don't scientists trust atoms? Because they make up everything!"},
        {"joke": "What did AWS say to the developer? You can't handle the cloud!"},
        {"joke": "Why was the JavaScript developer sad? Because he didn't Node how to Express himself!"},
        {"joke": "How many programmers does it take to change a light bulb? None, that's a hardware problem!"},
        {"joke": "Why do Java developers wear glasses? Because they don't C#!"}
    ]
    random_joke = random.choice(jokes)
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(random_joke)
    }
