import base64

with open('C:/Users/Prabh/.gemini/antigravity/brain/a3729446-dfba-4690-a2ef-50247953c206/honeychain-demo-qr.png', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode('utf-8')

html = f"""<!DOCTYPE html>
<html>
<head>
<style>
body {{
    display: flex;
    justify-content: center;
    align-items: center;
    margin: 0;
    background: transparent;
    overflow: hidden;
    padding: 20px;
}}
img {{
    max-width: 100%;
    max-height: 400px;
    border-radius: 12px;
}}
</style>
</head>
<body>
<img src="data:image/png;base64,{b64}" alt="QR Code" />
</body>
</html>"""

with open('C:/Users/Prabh/.gemini/antigravity/brain/a3729446-dfba-4690-a2ef-50247953c206/qr_widget.html', 'w', encoding='utf-8') as f:
    f.write(html)

