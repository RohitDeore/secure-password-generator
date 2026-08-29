curl -X POST "https://ffkk3kibm5pi2vx6iq64aarfuy0jkcbz.lambda-url.us-east-1.on.aws/"   -H "Content-Type: application/json"   -d '{"yesterday":"Fixed bug","today":"KEDA setup","blockers":"IAM approval","tone":"Professional & Clear"}'
curl -X POST "https://ffkk3kibm5pi2vx6iq64aarfuy0jkcbz.lambda-url.us-east-1.on.aws/"   -H "Content-Type: application/json"   -d '{"yesterday":"Fixed bug","today":"KEDA setup","blockers":"IAM approval","tone":"Professional & Clear"}'
cat << 'EOF' > lambda_function.py
import json
import boto3

bedrock = boto3.client(service_name='bedrock-runtime', region_name='us-east-1')

def lambda_handler(event, context):
    http_method = event.get('requestContext', {}).get('http', {}).get('method', '')
    if http_method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': ''
        }

    try:
        body = json.loads(event.get('body', '{}'))
        yesterday = body.get('yesterday', 'Completed assigned tasks')
        today = body.get('today', 'Continuing sprint backlog items')
        blockers = body.get('blockers', 'None')
        tone = body.get('tone', 'Professional & Clear')

        prompt = f"""
        You are an expert AI assistant helping a software engineer draft a daily stand-up update for Slack/Teams.
        
        Input Context:
        - Yesterday: {yesterday}
        - Today: {today}
        - Blockers: {blockers}
        - Requested Tone: {tone}

        Formatting Rules:
        1. Format into 3 distinct sections: Yesterday, Today, Blockers.
        2. Apply clear markdown/Slack formatting (e.g. bolding, bullet points, relevant emojis).
        3. Match the requested tone ({tone}).
        4. Keep the output concise and ready for immediate copy-pasting.
        """

        # Invoke Amazon Bedrock using Converse API with Amazon Nova Micro
        response = bedrock.converse(
            modelId='us.amazon.nova-micro-v1:0',
            messages=[
                {
                    'role': 'user',
                    'content': [{'text': prompt}]
                }
            ],
            inferenceConfig={'maxTokens': 300}
        )

        standup_text = response['output']['message']['content'][0]['text']

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'standup': standup_text})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }
EOF

# Zip and deploy code update
zip function.zip lambda_function.py
aws lambda update-function-code   --function-name StandUpGenerator   --zip-file fileb://function.zip
exit
cd ~
# 1. Create the Lambda code file
cat << 'EOF' > lambda_function.py
import json
import urllib.request
import urllib.parse
import ssl
import socket
from datetime import datetime, timezone

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Content-Type': 'application/json'
    }

    http_method = event.get('requestContext', {}).get('http', {}).get('method', '')
    if http_method == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers, 'body': ''}

    try:
        body = json.loads(event.get('body', '{}'))
        target_url = body.get('target_url', '').strip()

        if not target_url:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': 'Target URL is required.'})}

        if not target_url.startswith(('http://', 'https://')):
            target_url = 'https://' + target_url

        parsed_url = urllib.parse.urlparse(target_url)
        hostname = parsed_url.hostname
        if not hostname:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': 'Invalid URL format.'})}

        port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)

        # Measure Latency & Fetch HTTP Response Headers
        req = urllib.request.Request(target_url, headers={'User-Agent': 'AWS-Lambda-Security-Probe/1.0'})
        start_time = datetime.now(timezone.utc)
        
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        with urllib.request.urlopen(req, timeout=5, context=ctx) as response:
            latency_ms = round((datetime.now(timezone.utc) - start_time).total_seconds() * 1000, 2)
            status_code = response.status
            response_headers = {k.lower(): v for k, v in response.headers.items()}

        # Check Security Headers
        sec_headers = {
            'Strict-Transport-Security (HSTS)': 'strict-transport-security' in response_headers,
            'Content-Security-Policy (CSP)': 'content-security-policy' in response_headers,
            'X-Frame-Options': 'x-frame-options' in response_headers,
            'X-Content-Type-Options': 'x-content-type-options' in response_headers,
            'Referrer-Policy': 'referrer-policy' in response_headers
        }

        passed_count = sum(1 for v in sec_headers.values() if v)
        grade_map = {5: 'A+', 4: 'A', 3: 'B', 2: 'C', 1: 'D', 0: 'F'}
        security_grade = grade_map.get(passed_count, 'F')

        # SSL/TLS Certificate Audit
        ssl_audit = {}
        if parsed_url.scheme == 'https':
            try:
                ssl_ctx = ssl.create_default_context()
                with socket.create_connection((hostname, port), timeout=4) as sock:
                    with ssl_ctx.wrap_socket(sock, server_hostname=hostname) as ssock:
                        cert = ssock.getpeercert()
                        expire_date = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z').replace(tzinfo=timezone.utc)
                        days_left = (expire_date - datetime.now(timezone.utc)).days
                        issuer_dict = dict(x[0] for x in cert.get('issuer', ()))
                        issuer_org = issuer_dict.get('organizationName', issuer_dict.get('commonName', 'Unknown Issuer'))

                        ssl_audit = {
                            'valid': True,
                            'days_remaining': days_left,
                            'issuer': issuer_org,
                            'expires_on': expire_date.strftime('%Y-%m-%d UTC')
                        }
            except Exception as ssl_err:
                ssl_audit = {'valid': False, 'error': str(ssl_err)}

        result = {
            'target_url': target_url,
            'status_code': status_code,
            'latency_ms': latency_ms,
            'security_grade': security_grade,
            'security_headers': sec_headers,
            'ssl_audit': ssl_audit,
            'scanned_at': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
        }

        return {'statusCode': 200, 'headers': cors_headers, 'body': json.dumps({'result': result})}

    except Exception as e:
        return {'statusCode': 500, 'headers': cors_headers, 'body': json.dumps({'error': str(e)})}
EOF

# 2. Package into zip
zip probe_function.zip lambda_function.py
# 3. Create or Update Lambda Function
aws lambda create-function   --function-name SecurityProbeEngine   --runtime python3.12   --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/service-role/StandUpGenerator-role-1d4n953v   --handler lambda_function.lambda_handler   --zip-file fileb://probe_function.zip || aws lambda update-function-code   --function-name SecurityProbeEngine   --zip-file fileb://probe_function.zip
# 4. Configure Public Function URL
aws lambda create-function-url-config   --function-name SecurityProbeEngine   --auth-type NONE || true
# 5. Grant Public Access Permission
aws lambda add-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE || true
ls
rm standup-generator
rm -rf standup-generator
ls
cd ~
# 1. Create the IAM trust policy for Lambda
cat << 'EOF' > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# 2. Create the IAM Role for the Lambda function
aws iam create-role   --role-name SecurityProbeLambdaRole   --assume-role-policy-document file://trust-policy.json || true
# 3. Attach basic execution policy (CloudWatch logs permission)
aws iam attach-role-policy   --role-name SecurityProbeLambdaRole   --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true
# 4. Get Account ID and Role ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/SecurityProbeLambdaRole"
echo "Waiting 10 seconds for IAM role propagation..."
sleep 10
# 5. Create the Lambda Function
aws lambda create-function   --function-name SecurityProbeEngine   --runtime python3.12   --role ${ROLE_ARN}   --handler lambda_function.lambda_handler   --zip-file fileb://probe_function.zip || aws lambda update-function-code   --function-name SecurityProbeEngine   --zip-file fileb://probe_function.zip
# 6. Create the Public Function URL
aws lambda create-function-url-config   --function-name SecurityProbeEngine   --auth-type NONE || true
# 7. Grant Public Access Permission
aws lambda add-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE || true
# 8. Print your new Public Lambda Function URL
echo -e "\n======================================================="
echo "YOUR LIVE LAMBDA FUNCTION URL:"
aws lambda get-function-url-config --function-name SecurityProbeEngine --query "FunctionUrl" --output text
echo "======================================================="
curl -X POST "YOUR_LAMBDA_FUNCTION_URL_HERE"   -H "Content-Type: application/json"   -d '{"target_url": "https://github.com"}'
# 1. Fetch your live Lambda Function URL into a shell variable
LAMBDA_URL=$(aws lambda get-function-url-config --function-name SecurityProbeEngine --query "FunctionUrl" --output text)
# 2. Print your URL
echo "Testing URL: $LAMBDA_URL"
# 3. Test with curl
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"target_url": "https://github.com"}'
exit
# 1. Remove old permission statement (if any)
aws lambda remove-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess || true
# 2. Explicitly grant public access to the Function URL
aws lambda add-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
# 3. Fetch URL and test with curl
LAMBDA_URL=$(aws lambda get-function-url-config --function-name SecurityProbeEngine --query "FunctionUrl" --output text)
echo "Testing $LAMBDA_URL..."
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"target_url": "https://github.com"}'
exit
# 1. Update Function URL config to NONE auth type with full CORS enabled
aws lambda update-function-url-config   --function-name SecurityProbeEngine   --auth-type NONE   --cors '{"AllowOrigins":["*"],"AllowMethods":["OPTIONS","POST"],"AllowHeaders":["Content-Type"]}'
# 2. Remove any previous permission statement to prevent conflicts
aws lambda remove-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess || true
# 3. Add public invocation permission
aws lambda add-permission   --function-name SecurityProbeEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
# 4. Fetch the Function URL and test with curl
LAMBDA_URL=$(aws lambda get-function-url-config --function-name SecurityProbeEngine --query "FunctionUrl" --output text)
echo -e "\nTesting Function URL: $LAMBDA_URL\n"
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"target_url": "https://github.com"}'
exit
cd ~
echo "======================================================"
echo " 1. DELETING LAMBDA FUNCTIONS (us-east-1)"
echo "======================================================"
aws lambda delete-function --function-name StandUpGenerator --region us-east-1 2>/dev/null && echo "✅ Deleted Lambda: StandUpGenerator" || echo "ℹ️ StandUpGenerator not found / already deleted."
aws lambda delete-function --function-name SecurityProbeEngine --region us-east-1 2>/dev/null && echo "✅ Deleted Lambda: SecurityProbeEngine" || echo "ℹ️ SecurityProbeEngine not found / already deleted."
aws lambda delete-function --function-name DevToolsEngine --region us-east-1 2>/dev/null && echo "✅ Deleted Lambda: DevToolsEngine" || echo "ℹ️ DevToolsEngine not found / already deleted."
echo -e "\n======================================================"
echo " 2. DELETING CUSTOM IAM ROLES & POLICIES"
echo "======================================================"
# SecurityProbeLambdaRole cleanup
aws iam detach-role-policy --role-name SecurityProbeLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name SecurityProbeLambdaRole 2>/dev/null && echo "✅ Deleted IAM Role: SecurityProbeLambdaRole" || echo "ℹ️ SecurityProbeLambdaRole not found."
# DevToolsRole cleanup
aws iam detach-role-policy --role-name DevToolsRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name DevToolsRole 2>/dev/null && echo "✅ Deleted IAM Role: DevToolsRole" || echo "ℹ️ DevToolsRole not found."
echo -e "\n======================================================"
echo " 3. REMOVING LOCAL CLOUDSHELL FILES & SCRIPTS"
echo "======================================================"
rm -f lambda_function.py function.zip probe_function.zip devtools.zip trust-policy.json update_js.py
rm -rf standup-generator security-probe devtools-app
echo "✅ Local CloudShell directory cleaned."
echo -e "\n======================================================"
echo " 4. COST SAFETY VERIFICATION SUMMARY"
echo "======================================================"
echo "• Lambda Functions: All removed (0 background compute running)."
echo "• Amazon Bedrock: Uses pay-per-token pricing (0 charges when not being called)."
echo "• Amazon S3 / DynamoDB / EC2: None created."
echo "Your account will not incur recurring charges from these previous resources."
exit
cd ~
# 1. Create IAM Role Trust Policy
cat << 'EOF' > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# 2. Create IAM Role for Lambda
aws iam create-role --role-name DevToolsLambdaRole --assume-role-policy-document file://trust-policy.json 2>/dev/null || true
aws iam attach-role-policy --role-name DevToolsLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/DevToolsLambdaRole"
echo "Waiting 5 seconds for IAM role propagation..."
sleep 5
# 3. Create Lambda Python Code
cat << 'EOF' > lambda_function.py
import json
import base64
import hashlib

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Content-Type': 'application/json'
    }

    # Handle CORS OPTIONS preflight request
    http_method = event.get('requestContext', {}).get('http', {}).get('method', '')
    if http_method == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers, 'body': ''}

    try:
        body = json.loads(event.get('body', '{}'))
        action = body.get('action', '')
        text = body.get('text', '')

        if not text:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': 'Input text is required.'})}

        output = ''
        if action == 'sha256':
            output = hashlib.sha256(text.encode('utf-8')).hexdigest()
        elif action == 'md5':
            output = hashlib.md5(text.encode('utf-8')).hexdigest()
        elif action == 'encode_base64':
            output = base64.b64encode(text.encode('utf-8')).decode('utf-8')
        elif action == 'decode_base64':
            try:
                output = base64.b64decode(text.encode('utf-8')).decode('utf-8')
            except Exception:
                output = 'Error: Invalid Base64 string.'
        elif action == 'format_json':
            try:
                parsed = json.loads(text)
                output = json.dumps(parsed, indent=2)
            except Exception as e:
                output = f'JSON Syntax Error: {str(e)}'
        elif action == 'analyze':
            words = text.split()
            lines = text.splitlines()
            output = f"Characters: {len(text)} | Words: {len(words)} | Lines: {len(lines)}"
        else:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': f'Unsupported action: {action}'})}

        return {'statusCode': 200, 'headers': cors_headers, 'body': json.dumps({'result': output})}

    except Exception as e:
        return {'statusCode': 500, 'headers': cors_headers, 'body': json.dumps({'error': str(e)})}
EOF

# 4. Package and Deploy Lambda Function
zip devtools.zip lambda_function.py
aws lambda create-function   --function-name DevToolsEngine   --runtime python3.12   --role ${ROLE_ARN}   --handler lambda_function.lambda_handler   --zip-file fileb://devtools.zip 2>/dev/null || aws lambda update-function-code   --function-name DevToolsEngine   --zip-file fileb://devtools.zip
# 5. Create Public Function URL
aws lambda create-function-url-config   --function-name DevToolsEngine   --auth-type NONE 2>/dev/null || true
# 6. Set Public Access Permission
aws lambda remove-permission --function-name DevToolsEngine --statement-id FunctionURLAllowPublicAccess 2>/dev/null || true
aws lambda add-permission   --function-name DevToolsEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
# 7. Print Function URL and Run Automatic Test
LAMBDA_URL=$(aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text)
echo -e "\n======================================================="
echo "YOUR LIVE LAMBDA FUNCTION URL:"
echo "$LAMBDA_URL"
echo "=======================================================\n"
echo "Running Verification Test..."
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}'
aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text
cd ~
# 1. Create IAM Role Trust Policy
cat << 'EOF' > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# 2. Create IAM Role for Lambda
aws iam create-role --role-name DevToolsLambdaRole --assume-role-policy-document file://trust-policy.json 2>/dev/null || true
aws iam attach-role-policy --role-name DevToolsLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/DevToolsLambdaRole"
echo "Waiting 5 seconds for IAM role propagation..."
sleep 5
# 3. Create Lambda Python Code
cat << 'EOF' > lambda_function.py
import json
import base64
import hashlib

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Content-Type': 'application/json'
    }

    # Handle CORS OPTIONS preflight request
    http_method = event.get('requestContext', {}).get('http', {}).get('method', '')
    if http_method == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers, 'body': ''}

    try:
        body = json.loads(event.get('body', '{}'))
        action = body.get('action', '')
        text = body.get('text', '')

        if not text:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': 'Input text is required.'})}

        output = ''
        if action == 'sha256':
            output = hashlib.sha256(text.encode('utf-8')).hexdigest()
        elif action == 'md5':
            output = hashlib.md5(text.encode('utf-8')).hexdigest()
        elif action == 'encode_base64':
            output = base64.b64encode(text.encode('utf-8')).decode('utf-8')
        elif action == 'decode_base64':
            try:
                output = base64.b64decode(text.encode('utf-8')).decode('utf-8')
            except Exception:
                output = 'Error: Invalid Base64 string.'
        elif action == 'format_json':
            try:
                parsed = json.loads(text)
                output = json.dumps(parsed, indent=2)
            except Exception as e:
                output = f'JSON Syntax Error: {str(e)}'
        elif action == 'analyze':
            words = text.split()
            lines = text.splitlines()
            output = f"Characters: {len(text)} | Words: {len(words)} | Lines: {len(lines)}"
        else:
            return {'statusCode': 400, 'headers': cors_headers, 'body': json.dumps({'error': f'Unsupported action: {action}'})}

        return {'statusCode': 200, 'headers': cors_headers, 'body': json.dumps({'result': output})}

    except Exception as e:
        return {'statusCode': 500, 'headers': cors_headers, 'body': json.dumps({'error': str(e)})}
EOF

# 4. Package and Deploy Lambda Function
zip -q devtools.zip lambda_function.py
aws lambda create-function   --function-name DevToolsEngine   --runtime python3.12   --role ${ROLE_ARN}   --handler lambda_function.lambda_handler   --zip-file fileb://devtools.zip 2>/dev/null || aws lambda update-function-code   --function-name DevToolsEngine   --zip-file fileb://devtools.zip
# 5. Create Public Function URL
aws lambda create-function-url-config   --function-name DevToolsEngine   --auth-type NONE 2>/dev/null || true
# 6. Set Public Access Permission
aws lambda remove-permission --function-name DevToolsEngine --statement-id FunctionURLAllowPublicAccess 2>/dev/null || true
aws lambda add-permission   --function-name DevToolsEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
# 7. Print Function URL and Run Automatic Verification Test
LAMBDA_URL=$(aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text)
echo -e "\n======================================================="
echo "YOUR LIVE LAMBDA FUNCTION URL:"
echo "$LAMBDA_URL"
echo "=======================================================\n"
echo "Running Verification Test..."
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}'
echo -e "\n"
LAMBDA_URL=$(aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text)
echo "YOUR LAMBDA URL: $LAMBDA_URL"
exit
# 1. Configure CORS
aws lambda update-function-url-config   --function-name DevToolsEngine   --auth-type NONE   --cors '{"AllowOrigins":["*"],"AllowMethods":["*"],"AllowHeaders":["*"]}'
# 2. Grant Public Invoke Permission
aws lambda remove-permission --function-name DevToolsEngine --statement-id FunctionURLAllowPublicAccess 2>/dev/null || true
aws lambda add-permission   --function-name DevToolsEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
LAMBDA_URL=$(aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text)
echo "Testing SHA256..."
curl -s -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}' | python3 -m json.tool
echo "Testing Base64 Encode..."
curl -s -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"action": "encode_base64", "text": "Hello AWS Lambda"}' | python3 -m json.tool
exit
# 1. Delete old Function URL configuration to clear state
aws lambda delete-function-url-config --function-name DevToolsEngine 2>/dev/null || true
# 2. Cleanly recreate Function URL with NONE authentication
aws lambda create-function-url-config   --function-name DevToolsEngine   --auth-type NONE
# 3. Clear existing invocation permissions
aws lambda remove-permission   --function-name DevToolsEngine   --statement-id FunctionURLAllowPublicAccess 2>/dev/null || true
# 4. Add public invocation permission
aws lambda add-permission   --function-name DevToolsEngine   --statement-id FunctionURLAllowPublicAccess   --action lambda:InvokeFunctionUrl   --principal "*"   --function-url-auth-type NONE
# 5. Fetch new Function URL and test with curl
LAMBDA_URL=$(aws lambda get-function-url-config --function-name DevToolsEngine --query "FunctionUrl" --output text)
echo -e "\n======================================================="
echo "NEW LAMBDA FUNCTION URL:"
echo "$LAMBDA_URL"
echo "=======================================================\n"
echo "Testing SHA256..."
curl -X POST "$LAMBDA_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}'
echo -e "\n"
cd ~
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:DevToolsEngine"
# 1. Grant API Gateway permission to invoke Lambda
aws lambda add-permission   --function-name DevToolsEngine   --statement-id AllowAPIGatewayInvoke   --action lambda:InvokeFunction   --principal apigateway.amazonaws.com 2>/dev/null || true
# 2. Create HTTP API directly connected to DevToolsEngine
API_ID=$(aws apigatewayv2 create-api \
  --name DevToolsHTTPAPI \
  --protocol-type HTTP \
  --target ${LAMBDA_ARN} \
  --cors-configuration 'AllowOrigins=["*"],AllowMethods=["*"],AllowHeaders=["*"]' \
  --query "ApiId" --output text)
# 3. Get public API Endpoint
API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/"
echo -e "\n======================================================="
echo "YOUR LIVE API GATEWAY URL:"
echo "$API_URL"
echo "=======================================================\n"
echo "Testing API Gateway with curl..."
curl -X POST "$API_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}'
echo -e "\n"
cd ~
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:DevToolsEngine"
# 1. Grant API Gateway permission to invoke Lambda
aws lambda remove-permission --function-name DevToolsEngine --statement-id AllowAPIGatewayInvoke 2>/dev/null || true
aws lambda add-permission   --function-name DevToolsEngine   --statement-id AllowAPIGatewayInvoke   --action lambda:InvokeFunction   --principal apigateway.amazonaws.com   --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:*/*"
# 2. Delete any existing API Gateway named DevToolsAPI to clean up
OLD_API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='DevToolsAPI'].ApiId" --output text)
if [ -n "$OLD_API_ID" ]; then   aws apigatewayv2 delete-api --api-id "$OLD_API_ID"; fi
# 3. Create HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name DevToolsAPI \
  --protocol-type HTTP \
  --cors-configuration '{"AllowOrigins":["*"],"AllowMethods":["*"],"AllowHeaders":["*"]}' \
  --query "ApiId" --output text)
# 4. Create Integration with Lambda
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id ${API_ID} \
  --integration-type AWS_PROXY \
  --integration-method POST \
  --payload-format-version "2.0" \
  --integration-uri ${LAMBDA_ARN} \
  --query "IntegrationId" --output text)
# 5. Create Routes for / and /{proxy+}
aws apigatewayv2 create-route   --api-id ${API_ID}   --route-key "ANY /"   --target "integrations/${INTEGRATION_ID}"
aws apigatewayv2 create-route   --api-id ${API_ID}   --route-key "ANY /{proxy+}"   --target "integrations/${INTEGRATION_ID}"
# 6. Create $default Stage with Auto-Deploy
aws apigatewayv2 create-stage   --api-id ${API_ID}   --stage-name '$default'   --auto-deploy
# 7. Print and Test URL
API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/"
echo -e "\n======================================================="
echo "YOUR WORKING API GATEWAY URL:"
echo "$API_URL"
echo "=======================================================\n"
echo "Testing SHA256 operation with curl..."
curl -X POST "$API_URL"   -H "Content-Type: application/json"   -d '{"action": "sha256", "text": "Hello AWS Lambda"}'
echo -e "\n"
exit
