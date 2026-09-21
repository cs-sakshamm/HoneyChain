import base64

with open('C:/Users/Prabh/.gemini/antigravity/brain/a3729446-dfba-4690-a2ef-50247953c206/honeychain-sih-qr.png', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode('utf-8')

html = f"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ 
            display: flex; 
            flex-direction: column;
            justify-content: center; 
            align-items: center; 
            margin: 0; 
            background: transparent; 
            overflow: hidden; 
            padding: 20px; 
            font-family: system-ui, -apple-system, sans-serif;
        }}
        img {{ 
            max-width: 100%; 
            max-height: 400px; 
            border-radius: 12px; 
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
        }}
        .btn {{
            margin-top: 24px;
            padding: 12px 24px;
            background-color: #10b981;
            color: white;
            text-decoration: none;
            border-radius: 9999px;
            font-weight: 700;
            font-size: 14px;
            transition: transform 0.2s, background-color 0.2s;
            box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
        }}
        .btn:hover {{
            background-color: #059669;
            transform: translateY(-2px);
        }}
    </style>
</head>
<body>
    <img src="data:image/png;base64,{b64}" alt="HoneyChain QR Code" />
    <a href="data:image/png;base64,{b64}" download="HoneyChain-SIH-2026-QR.png" class="btn">
        ↓ Download QR Code
    </a>
</body>
</html>
"""

with open('C:/Users/Prabh/.gemini/antigravity/brain/a3729446-dfba-4690-a2ef-50247953c206/qr_widget.html', 'w', encoding='utf-8') as f:
    f.write(html)
