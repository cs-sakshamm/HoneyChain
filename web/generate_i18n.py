import json

base = {
  "logoText": "HoneyChain",
  "greeting": "Welcome to HoneyChain",
  "aboutIntro": "The world's first cryptographically secure provenance platform for authentic, unadulterated honey.",
  "verifyOrigin": "Verify Origin",
  "enterBatch": "Enter a batch identifier to inspect the tamper-evident provenance.",
  "batchIdLabel": "Batch ID",
  "verifyBtn": "VERIFY",
  "footerCopy": "HoneyChain. Team DataMineX.",
  "nav": { "About": "About", "Traceability": "Traceability", "Technology": "Technology", "Laboratory": "Laboratory", "Contact": "Contact" },
  "close": "Close",
  "pv": {
    "loading": "Verifying record...",
    "error": "Verification service is temporarily unavailable.",
    "notFound": "Record not found",
    "title": "Product Verification",
    "pending": "PENDING",
    "verified": "VERIFIED",
    "traceId": "Trace ID",
    "nodes": {
      "harvester": "01 Harvester",
      "hive": "02 Hive",
      "collection": "03 Collection",
      "laboratory": "04 Lab Test",
      "lab_report": "05 Lab Report",
      "packaging": "06 Packaging"
    },
    "traceability": "Complete Traceability"
  }
}

out_dict = {"EN": base}

out_dict["HI"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेन में आपका स्वागत है",
  "aboutIntro": "प्रामाणिक, बिना मिलावट वाले शहद के लिए दुनिया का पहला क्रिप्टोग्राफ़िक रूप से सुरक्षित मंच।",
  "verifyOrigin": "उत्पत्ति सत्यापित करें", "enterBatch": "बैच पहचानकर्ता दर्ज करें।",
  "batchIdLabel": "बैच आईडी", "verifyBtn": "सत्यापित करें", "footerCopy": "हनीचेन। टीम DataMineX।",
  "nav": { "About": "हमारे बारे में", "Traceability": "ट्रैसेबिलिटी", "Technology": "प्रौद्योगिकी", "Laboratory": "प्रयोगशाला", "Contact": "संपर्क" },
  "close": "बंद करें",
  "pv": { "loading": "सत्यापित हो रहा है...", "error": "सेवा अनुपलब्ध है।", "notFound": "रिकॉर्ड नहीं मिला", "title": "उत्पाद सत्यापन", "pending": "लंबित", "verified": "सत्यापित", "traceId": "ट्रेस आईडी", "nodes": { "harvester": "01 फसल", "hive": "02 छत्ता", "collection": "03 संग्रह", "laboratory": "04 लैब टेस्ट", "lab_report": "05 लैब रिपोर्ट", "packaging": "06 पैकेजिंग" }, "traceability": "संपूर्ण ट्रैसेबिलिटी" }
}

out_dict["BN"] = {
  "logoText": "হানিশেইন", "greeting": "হানিশেইনে স্বাগতম",
  "aboutIntro": "খাঁটি, ভেজালহীন মধুর জন্য বিশ্বের প্রথম সুরক্ষিত প্ল্যাটফর্ম।",
  "verifyOrigin": "উৎস যাচাই করুন", "enterBatch": "ব্যাচ শনাক্তকারী লিখুন।",
  "batchIdLabel": "ব্যাচ আইডি", "verifyBtn": "যাচাই করুন", "footerCopy": "হানিশেইন। টিম DataMineX।",
  "nav": { "About": "সম্পর্কে", "Traceability": "ট্রেসিবিলিটি", "Technology": "প্রযুক্তি", "Laboratory": "ল্যাব", "Contact": "যোগাযোগ" },
  "close": "বন্ধ করুন",
  "pv": { "loading": "যাচাই করা হচ্ছে...", "error": "পরিষেবা অনুপলব্ধ।", "notFound": "পাওয়া যায়নি", "title": "পণ্য যাচাইকরণ", "pending": "অমীমাংসিত", "verified": "যাচাইকৃত", "traceId": "ট্রেস আইডি", "nodes": { "harvester": "01 ফসল", "hive": "02 মৌচাক", "collection": "03 সংগ্রহ", "laboratory": "04 ল্যাব টেস্ট", "lab_report": "05 ল্যাব রিপোর্ট", "packaging": "06 প্যাকেজিং" }, "traceability": "সম্পূর্ণ ট্রেসিবিলিটি" }
}

out_dict["TE"] = {
  "logoText": "హనీచెయిన్", "greeting": "హనీచెయిన్‌కు స్వాగతం",
  "aboutIntro": "స్వచ్ఛమైన తేనె కోసం ప్రపంచంలోనే మొట్టమొదటి సురక్షిత ప్లాట్‌ఫారమ్.",
  "verifyOrigin": "మూలాన్ని ధృవీకరించండి", "enterBatch": "బ్యాచ్ ఐడిని నమోదు చేయండి.",
  "batchIdLabel": "బ్యాచ్ ఐడి", "verifyBtn": "ధృవీకరించండి", "footerCopy": "హనీచెయిన్. బృందం DataMineX.",
  "nav": { "About": "గురించి", "Traceability": "ట్రేసిబిలిటీ", "Technology": "సాంకేతికత", "Laboratory": "ప్రయోగశాల", "Contact": "సంప్రదించండి" },
  "close": "మూసివేయి",
  "pv": { "loading": "ధృవీకరించబడుతోంది...", "error": "సేవ అందుబాటులో లేదు.", "notFound": "కనుగొనబడలేదు", "title": "ఉత్పత్తి ధృవీకరణ", "pending": "పెండింగ్", "verified": "ధృవీకరించబడింది", "traceId": "ట్రేస్ ఐడి", "nodes": { "harvester": "01 పంట", "hive": "02 తేనెపట్టు", "collection": "03 సేకరణ", "laboratory": "04 ల్యాబ్ పరీక్ష", "lab_report": "05 ల్యాబ్ నివేదిక", "packaging": "06 ప్యాకేజింగ్" }, "traceability": "పూర్తి ట్రేసిబిలిటీ" }
}

out_dict["MR"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेन मध्ये आपले स्वागत आहे",
  "aboutIntro": "अस्सल मधासाठी जगातील पहिले सुरक्षित प्लॅटफॉर्म.",
  "verifyOrigin": "मूळ सत्यापित करा", "enterBatch": "बॅच आयडी प्रविष्ट करा.",
  "batchIdLabel": "बॅच आयडी", "verifyBtn": "सत्यापित करा", "footerCopy": "हनीचेन. टीम DataMineX.",
  "nav": { "About": "आमच्याबद्दल", "Traceability": "ट्रेसेबिलिटी", "Technology": "तंत्रज्ञान", "Laboratory": "प्रयोगशाळा", "Contact": "संपर्क" },
  "close": "बंद करा",
  "pv": { "loading": "सत्यापित होत आहे...", "error": "सेवा अनुपलब्ध आहे.", "notFound": "आढळले नाही", "title": "उत्पादन सत्यापन", "pending": "प्रलंबित", "verified": "सत्यापित", "traceId": "ट्रेस आयडी", "nodes": { "harvester": "01 कापणी", "hive": "02 पोळे", "collection": "03 संग्रह", "laboratory": "04 लॅब चाचणी", "lab_report": "05 लॅब रिपोर्ट", "packaging": "06 पॅकेजिंग" }, "traceability": "संपूर्ण ट्रेसेबिलिटी" }
}

out_dict["TA"] = {
  "logoText": "ஹனிசெயின்", "greeting": "ஹனிசெயினுக்கு வரவேற்கிறோம்",
  "aboutIntro": "உண்மையான தேனுக்கான உலகின் முதல் பாதுகாப்பு தளம்.",
  "verifyOrigin": "தோற்றத்தை சரிபார்க்கவும்", "enterBatch": "பேட்ச் ஐடியை உள்ளிடவும்.",
  "batchIdLabel": "பேட்ச் ஐடி", "verifyBtn": "சரிபார்", "footerCopy": "ஹனிசெயின். குழு DataMineX.",
  "nav": { "About": "பற்றி", "Traceability": "கண்காணிப்பு", "Technology": "தொழில்நுட்பம்", "Laboratory": "ஆய்வகம்", "Contact": "தொடர்பு" },
  "close": "மூடு",
  "pv": { "loading": "சரிபார்க்கப்படுகிறது...", "error": "சேவை கிடைக்கவில்லை.", "notFound": "கிடைக்கவில்லை", "title": "தயாரிப்பு சரிபார்ப்பு", "pending": "நிலுவையில்", "verified": "சரிபார்க்கப்பட்டது", "traceId": "சுவடு ஐடி", "nodes": { "harvester": "01 அறுவடை", "hive": "02 தேன்கூடு", "collection": "03 சேகரிப்பு", "laboratory": "04 சோதனை", "lab_report": "05 அறிக்கை", "packaging": "06 பேக்கேஜிங்" }, "traceability": "முழுமையான கண்காணிப்பு" }
}

out_dict["UR"] = {
  "logoText": "ہنی چین", "greeting": "ہنی چین میں خوش آمدید",
  "aboutIntro": "خالص شہد کے لیے دنیا کا پہلا محفوظ پلیٹ فارم۔",
  "verifyOrigin": "اصل کی تصدیق کریں", "enterBatch": "بیچ آئی ڈی درج کریں۔",
  "batchIdLabel": "بیچ آئی ڈی", "verifyBtn": "تصدیق کریں", "footerCopy": "ہنی چین. ٹیم DataMineX.",
  "nav": { "About": "بارے میں", "Traceability": "ٹریس ایبلٹی", "Technology": "ٹیکنالوجی", "Laboratory": "لیبارٹری", "Contact": "رابطہ" },
  "close": "بند کریں",
  "pv": { "loading": "تصدیق ہو رہی ہے...", "error": "سروس دستیاب نہیں ہے۔", "notFound": "نہیں ملا", "title": "پروڈکٹ کی تصدیق", "pending": "زیر التواء", "verified": "تصدیق شدہ", "traceId": "ٹریس آئی ڈی", "nodes": { "harvester": "01 کٹائی", "hive": "02 چھتہ", "collection": "03 مجموعہ", "laboratory": "04 ٹیسٹ", "lab_report": "05 رپورٹ", "packaging": "06 پیکیجنگ" }, "traceability": "مکمل ٹریس ایبلٹی" }
}

out_dict["GU"] = {
  "logoText": "હનીચેન", "greeting": "હનીચેનમાં સ્વાગત છે",
  "aboutIntro": "શુદ્ધ મધ માટે વિશ્વનું પ્રથમ સુરક્ષિત પ્લેટફોર્મ.",
  "verifyOrigin": "મૂળ ચકાસો", "enterBatch": "બેચ આઈડી દાખલ કરો.",
  "batchIdLabel": "બેચ આઈડી", "verifyBtn": "ચકાસો", "footerCopy": "હનીચેન. ટીમ DataMineX.",
  "nav": { "About": "વિશે", "Traceability": "ટ્રેસેબિલિટી", "Technology": "ટેકનોલોજી", "Laboratory": "લેબ", "Contact": "સંપર્ક" },
  "close": "બંધ કરો",
  "pv": { "loading": "ચકાસાયેલ છે...", "error": "સેવા અનુપલબ્ધ.", "notFound": "મળ્યો નથી", "title": "ઉત્પાદન ચકાસણી", "pending": "બાકી છે", "verified": "ચકાસાયેલ", "traceId": "ટ્રેસ આઈડી", "nodes": { "harvester": "01 લણણી", "hive": "02 મધપૂડો", "collection": "03 સંગ્રહ", "laboratory": "04 ટેસ્ટ", "lab_report": "05 રિપોર્ટ", "packaging": "06 પેકેજિંગ" }, "traceability": "સંપૂર્ણ ટ્રેસેબિલિટી" }
}

out_dict["KN"] = {
  "logoText": "ಹನಿಚೈನ್", "greeting": "ಹನಿಚೈನ್‌ಗೆ ಸ್ವಾಗತ",
  "aboutIntro": "ಶುದ್ಧ ಜೇನುತುಪ್ಪಕ್ಕಾಗಿ ವಿಶ್ವದ ಮೊದಲ ಸುರಕ್ಷಿತ ವೇದಿಕೆ.",
  "verifyOrigin": "ಮೂಲ ಪರಿಶೀಲಿಸಿ", "enterBatch": "ಬ್ಯಾಚ್ ಐಡಿ ನಮೂದಿಸಿ.",
  "batchIdLabel": "ಬ್ಯಾಚ್ ಐಡಿ", "verifyBtn": "ಪರಿಶೀಲಿಸಿ", "footerCopy": "ಹನಿಚೈನ್. ತಂಡ DataMineX.",
  "nav": { "About": "ಬಗ್ಗೆ", "Traceability": "ಪತ್ತೆಹಚ್ಚುವಿಕೆ", "Technology": "ತಂತ್ರಜ್ಞಾನ", "Laboratory": "ಪ್ರಯೋಗಾಲಯ", "Contact": "ಸಂಪರ್ಕ" },
  "close": "ಮುಚ್ಚಿ",
  "pv": { "loading": "ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...", "error": "ಸೇವೆ ಲಭ್ಯವಿಲ್ಲ.", "notFound": "ಕಂಡುಬಂದಿಲ್ಲ", "title": "ಉತ್ಪನ್ನ ಪರಿಶೀಲನೆ", "pending": "ಬಾಕಿ ಇದೆ", "verified": "ಪರಿಶೀಲಿಸಲಾಗಿದೆ", "traceId": "ಟ್ರೇಸ್ ಐಡಿ", "nodes": { "harvester": "01 ಸುಗ್ಗಿ", "hive": "02 ಜೇನುಗೂಡು", "collection": "03 ಸಂಗ್ರಹಣೆ", "laboratory": "04 ಪರೀಕ್ಷೆ", "lab_report": "05 ವರದಿ", "packaging": "06 ಪ್ಯಾಕೇಜಿಂಗ್" }, "traceability": "ಸಂಪೂರ್ಣ ಪತ್ತೆಹಚ್ಚುವಿಕೆ" }
}

out_dict["OR"] = {
  "logoText": "ହନିଚେନ୍", "greeting": "ହନିଚେନ୍ କୁ ସ୍ଵାଗତ",
  "aboutIntro": "ଖାଣ୍ଟି ମହୁ ପାଇଁ ବିଶ୍ଵର ପ୍ରଥମ ସୁରକ୍ଷିତ ପ୍ଲାଟଫର୍ମ।",
  "verifyOrigin": "ଉତ୍ସ ଯାଞ୍ଚ କରନ୍ତୁ", "enterBatch": "ବ୍ୟାଚ୍ ଆଇଡି ଦିଅନ୍ତୁ।",
  "batchIdLabel": "ବ୍ୟାଚ୍ ଆଇଡି", "verifyBtn": "ଯାଞ୍ଚ କରନ୍ତୁ", "footerCopy": "ହନିଚେନ୍। ଟିମ୍ DataMineX।",
  "nav": { "About": "ବିଷୟରେ", "Traceability": "ଟ୍ରେସେବିଲିଟି", "Technology": "ପ୍ରଯୁକ୍ତି", "Laboratory": "ପରୀକ୍ଷାଗାର", "Contact": "ଯୋଗାଯୋଗ" },
  "close": "ବନ୍ଦ କରନ୍ତୁ",
  "pv": { "loading": "ଯାଞ୍ଚ ହେଉଛି...", "error": "ସେବା ଉପଲବ୍ଧ ନାହିଁ।", "notFound": "ମିଳିଲା ନାହିଁ", "title": "ଉତ୍ପାଦ ଯାଞ୍ଚ", "pending": "ବାକି ଅଛି", "verified": "ଯାଞ୍ଚ ହେଲା", "traceId": "ଟ୍ରେସ୍ ଆଇଡି", "nodes": { "harvester": "01 ଅମଳ", "hive": "02 ମହୁଫେଣା", "collection": "03 ସଂଗ୍ରହ", "laboratory": "04 ଟେଷ୍ଟ", "lab_report": "05 ରିପୋର୍ଟ", "packaging": "06 ପ୍ୟାକେଜିଂ" }, "traceability": "ସମ୍ପୂର୍ଣ୍ଣ ଟ୍ରେସେବିଲିଟି" }
}

out_dict["ML"] = {
  "logoText": "ഹണിചെയിൻ", "greeting": "ഹണിചെയിനിലേക്ക് സ്വാഗതം",
  "aboutIntro": "യഥാർത്ഥ തേനിനായുള്ള ലോകത്തിലെ ആദ്യത്തെ സുരക്ഷിത പ്ലാറ്റ്ഫോം.",
  "verifyOrigin": "ഉറവിടം പരിശോധിക്കുക", "enterBatch": "ബാച്ച് ഐഡി നൽകുക.",
  "batchIdLabel": "ബാച്ച് ഐഡി", "verifyBtn": "പരിശോധിക്കുക", "footerCopy": "ഹണിചെയിൻ. ടീം DataMineX.",
  "nav": { "About": "കുറിച്ച്", "Traceability": "കണ്ടെത്തൽ", "Technology": "സാങ്കേതികവിദ്യ", "Laboratory": "ലാബ്", "Contact": "ബന്ധപ്പെടുക" },
  "close": "അടയ്ക്കുക",
  "pv": { "loading": "പരിശോധിക്കുന്നു...", "error": "സേവനം ലഭ്യമല്ല.", "notFound": "കണ്ടെത്തിയില്ല", "title": "ഉൽപ്പന്ന പരിശോധന", "pending": "തീരുമാനമായിട്ടില്ല", "verified": "പരിശോധിച്ചു", "traceId": "ട്രേസ് ഐഡി", "nodes": { "harvester": "01 വിളവെടുപ്പ്", "hive": "02 തേനീച്ചക്കൂട്", "collection": "03 ശേഖരണം", "laboratory": "04 ടെസ്റ്റ്", "lab_report": "05 റിപ്പോർട്ട്", "packaging": "06 പാക്കേജിംഗ്" }, "traceability": "പൂർണ്ണമായ കണ്ടെത്തൽ" }
}

out_dict["PA"] = {
  "logoText": "ਹਨੀਚੇਨ", "greeting": "ਹਨੀਚੇਨ ਵਿੱਚ ਸਵਾਗਤ ਹੈ",
  "aboutIntro": "ਅਸਲੀ ਸ਼ਹਿਦ ਲਈ ਦੁਨੀਆ ਦਾ ਪਹਿਲਾ ਸੁਰੱਖਿਅਤ ਪਲੇਟਫਾਰਮ.",
  "verifyOrigin": "ਮੂਲ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ", "enterBatch": "ਬੈਚ ਆਈਡੀ ਦਰਜ ਕਰੋ।",
  "batchIdLabel": "ਬੈਚ ਆਈਡੀ", "verifyBtn": "ਪੁਸ਼ਟੀ ਕਰੋ", "footerCopy": "ਹਨੀਚੇਨ। ਟੀਮ DataMineX।",
  "nav": { "About": "ਬਾਰੇ", "Traceability": "ਟਰੇਸੇਬਿਲਿਟੀ", "Technology": "ਤਕਨਾਲੋਜੀ", "Laboratory": "ਪ੍ਰਯੋਗਸ਼ਾਲਾ", "Contact": "ਸੰਪਰਕ" },
  "close": "ਬੰਦ ਕਰੋ",
  "pv": { "loading": "ਪੁਸ਼ਟੀ ਹੋ ਰਹੀ ਹੈ...", "error": "ਸੇਵਾ ਉਪਲਬਧ ਨਹੀਂ ਹੈ.", "notFound": "ਨਹੀਂ ਮਿਲਿਆ", "title": "ਉਤਪਾਦ ਦੀ ਪੁਸ਼ਟੀ", "pending": "ਲੰਬਿਤ", "verified": "ਪ੍ਰਮਾਣਿਤ", "traceId": "ਟਰੇਸ ਆਈਡੀ", "nodes": { "harvester": "01 ਵਾਢੀ", "hive": "02 ਛੱਤਾ", "collection": "03 ਸੰਗ੍ਰਹਿ", "laboratory": "04 ਟੈਸਟ", "lab_report": "05 ਰਿਪੋਰਟ", "packaging": "06 ਪੈਕੇਜਿੰਗ" }, "traceability": "ਪੂਰੀ ਟਰੇਸੇਬਿਲਿਟੀ" }
}

out_dict["AS"] = {
  "logoText": "হানিচেইন", "greeting": "হানিচেইনলৈ স্বাগতম",
  "aboutIntro": "খাঁটি মৌৰ বাবে বিশ্বৰ প্ৰথম সুৰক্ষিত প্লেটফৰ্ম।",
  "verifyOrigin": "উৎস পৰীক্ষা কৰক", "enterBatch": "বেচ আইডি দিয়ক।",
  "batchIdLabel": "বেচ আইডি", "verifyBtn": "পৰীক্ষা কৰক", "footerCopy": "হানিচেইন। টীম DataMineX।",
  "nav": { "About": "বিষয়ে", "Traceability": "ট্ৰেচিবিলিটি", "Technology": "প্ৰযুক্তি", "Laboratory": "গৱেষণাগাৰ", "Contact": "যোগাযোগ" },
  "close": "বন্ধ কৰক",
  "pv": { "loading": "পৰীক্ষা কৰা হৈছে...", "error": "সেৱা উপলব্ধ নহয়।", "notFound": "পোৱা নগ'ল", "title": "পণ্য পৰীক্ষাকৰণ", "pending": "বাকী আছে", "verified": "পৰীক্ষা কৰা হ'ল", "traceId": "ট্ৰেচ আইডি", "nodes": { "harvester": "01 শস্য চপোৱা", "hive": "02 মৌচাক", "collection": "03 সংগ্ৰহ", "laboratory": "04 টেষ্ট", "lab_report": "05 ৰিপৰ্ট", "packaging": "06 পেকেজিং" }, "traceability": "সম্পূৰ্ণ ট্ৰেচিবিলিটি" }
}

out_dict["DOI"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेन च तुंदा स्वागत ऐ",
  "aboutIntro": "असली शहद लेई दुनियै दा पहला सुरक्षित प्लेटफार्म।",
  "verifyOrigin": "मूल दी पुष्टिकरण करो", "enterBatch": "बैच आईडी दर्ज करो।",
  "batchIdLabel": "बैच आईडी", "verifyBtn": "पुष्टि करो", "footerCopy": "हनीचेन। टीम DataMineX।",
  "nav": { "About": "बारे च", "Traceability": "ट्रेसेबिलिटी", "Technology": "तकनीक", "Laboratory": "लैब", "Contact": "संपर्क" },
  "close": "बंद करो",
  "pv": { "loading": "पुष्टि होआ करदी ऐ...", "error": "सेवा उपलब्ध नेईं।", "notFound": "नेईं लब्भा", "title": "उत्पाद पुष्टि", "pending": "लंबित", "verified": "प्रमाणित", "traceId": "ट्रेस आईडी", "nodes": { "harvester": "01 फसल", "hive": "02 छत्ता", "collection": "03 संग्रह", "laboratory": "04 टेस्ट", "lab_report": "05 रिपोर्ट", "packaging": "06 पैकेजिंग" }, "traceability": "पूरी ट्रेसेबिलिटी" }
}

out_dict["KOK"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेनंत येवकार",
  "aboutIntro": "खऱ्या म्हावा खातीर जगांतलो पयलो सुरक्षित प्लॅटफॉर्म.",
  "verifyOrigin": "मूळ तपासात", "enterBatch": "बॅच आयडी दियात.",
  "batchIdLabel": "बॅच आयडी", "verifyBtn": "तपासात", "footerCopy": "हनीचेन. पंगड DataMineX.",
  "nav": { "About": "विशीं", "Traceability": "ट्रेसेबिलिटी", "Technology": "तंत्रज्ञान", "Laboratory": "लॅब", "Contact": "संपर्क" },
  "close": "बंद करात",
  "pv": { "loading": "तपासणी चालू आसा...", "error": "सेवा उपलब्ध ना.", "notFound": "मेळ्ळें ना", "title": "उत्पादन तपासणी", "pending": "बाकी आसा", "verified": "तपासलें", "traceId": "ट्रेस आयडी", "nodes": { "harvester": "01 कापणी", "hive": "02 मोंव", "collection": "03 संग्रह", "laboratory": "04 टेस्ट", "lab_report": "05 रिपोर्ट", "packaging": "06 पॅकेजिंग" }, "traceability": "पुराय ट्रेसेबिलिटी" }
}

out_dict["MAI"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेन मे अहाँक स्वागत अछि",
  "aboutIntro": "असली मधु लेल दुनियाक पहिल सुरक्षित प्लेटफार्म।",
  "verifyOrigin": "मूलक सत्यापन करू", "enterBatch": "बैच आईडी दर्ज करू।",
  "batchIdLabel": "बैच आईडी", "verifyBtn": "सत्यापन करू", "footerCopy": "हनीचेन। टीम DataMineX।",
  "nav": { "About": "विषय मे", "Traceability": "ट्रेसेबिलिटी", "Technology": "तकनीक", "Laboratory": "लैब", "Contact": "संपर्क" },
  "close": "बंद करू",
  "pv": { "loading": "सत्यापन भ रहल अछि...", "error": "सेवा उपलब्ध नहि अछि।", "notFound": "नहि भेटल", "title": "उत्पाद सत्यापन", "pending": "लंबित", "verified": "सत्यापित", "traceId": "ट्रेस आईडी", "nodes": { "harvester": "01 फसल", "hive": "02 छत्ता", "collection": "03 संग्रह", "laboratory": "04 टेस्ट", "lab_report": "05 रिपोर्ट", "packaging": "06 पैकेजिंग" }, "traceability": "पूर्ण ट्रेसेबिलिटी" }
}

out_dict["MNI"] = {
  "logoText": "ꯍꯅꯤꯆꯦꯟ", "greeting": "ꯍꯅꯤꯆꯦꯟꯗ ꯇꯔꯥꯝꯅ ꯑꯣꯛꯆꯔꯤ",
  "aboutIntro": "ꯑꯁꯦꯡꯕ ꯈꯣꯏꯍꯤꯒꯤꯗꯃꯛ ꯃꯥꯂꯦꯝꯒꯤ ꯑꯍꯥꯟꯕ ꯁꯦꯛꯌꯨꯔ ꯄ꯭ꯂꯦꯠꯐꯣꯔꯝ꯫",
  "verifyOrigin": "ꯍꯧꯔꯛꯐꯝ ꯌꯦꯡꯕꯤꯌꯨ", "enterBatch": "ꯕꯦꯆ ꯑꯥꯏꯗꯤ ꯍꯥꯞꯄꯤꯌꯨ꯫",
  "batchIdLabel": "ꯕꯦꯆ ꯑꯥꯏꯗꯤ", "verifyBtn": "ꯌꯦꯡꯕꯤꯌꯨ", "footerCopy": "ꯍꯅꯤꯆꯦꯟ꯫ ꯇꯤꯝ DataMineX꯫",
  "nav": { "About": "ꯃꯔꯝꯗ", "Traceability": "ꯇ꯭ꯔꯦꯁꯦꯕꯤꯂꯤꯇꯤ", "Technology": "ꯇꯦꯛꯅꯣꯂꯣꯖꯤ", "Laboratory": "ꯂꯦꯕ", "Contact": "ꯀꯟꯇꯦꯛ" },
  "close": "ꯊꯤꯡꯖꯤꯟꯕ",
  "pv": { "loading": "ꯌꯦꯡꯁꯤꯟꯔꯤ...", "error": "ꯁꯔꯚꯤꯁ ꯐꯪꯗ꯭ꯔꯤ꯫", "notFound": "ꯐꯪꯗꯦ", "title": "ꯄꯣꯊꯣꯛ ꯌꯦꯡꯁꯤꯟꯕ", "pending": "ꯄꯦꯟꯗꯤꯡ", "verified": "ꯚꯦꯔꯤꯐꯥꯏꯗ", "traceId": "ꯇ꯭ꯔꯦꯁ ꯑꯥꯏꯗꯤ", "nodes": { "harvester": "01 ꯂꯧꯔꯣꯛ", "hive": "02 ꯈꯣꯏꯔꯣꯝ", "collection": "03 ꯈꯣꯝꯖꯤꯟꯕ", "laboratory": "04 ꯇꯦꯁ꯭ꯠ", "lab_report": "05 ꯔꯤꯄꯣꯔꯠ", "packaging": "06 ꯄꯦꯀꯦꯖꯤꯡ" }, "traceability": "ꯃꯄꯨꯡꯐꯥꯕ ꯇ꯭ꯔꯦꯁꯦꯕꯤꯂꯤꯇꯤ" }
}

out_dict["NE"] = {
  "logoText": "हनीचेन", "greeting": "हनीचेनमा स्वागत छ",
  "aboutIntro": "शुद्ध महको लागि विश्वको पहिलो सुरक्षित प्लेटफर्म।",
  "verifyOrigin": "मूल प्रमाणित गर्नुहोस्", "enterBatch": "ब्याच आईडी प्रविष्ट गर्नुहोस्।",
  "batchIdLabel": "ब्याच आईडी", "verifyBtn": "प्रमाणित गर्नुहोस्", "footerCopy": "हनीचेन। टीम DataMineX।",
  "nav": { "About": "बारेमा", "Traceability": "ट्रेसेबिलिटी", "Technology": "प्रविधि", "Laboratory": "ल्याब", "Contact": "सम्पर्क" },
  "close": "बन्द गर्नुहोस्",
  "pv": { "loading": "प्रमाणित हुँदैछ...", "error": "सेवा उपलब्ध छैन।", "notFound": "फेला परेन", "title": "उत्पादन प्रमाणीकरण", "pending": "बाँकी छ", "verified": "प्रमाणित", "traceId": "ट्रेस आईडी", "nodes": { "harvester": "01 फसल", "hive": "02 घार", "collection": "03 सङ्कलन", "laboratory": "04 टेस्ट", "lab_report": "05 रिपोर्ट", "packaging": "06 प्याकेजिङ" }, "traceability": "पूर्ण ट्रेसेबिलिटी" }
}

out_dict["SA"] = {
  "logoText": "मधुशृङ्खला", "greeting": "मधुशृङ्खलायां स्वागतम्",
  "aboutIntro": "शुद्धमधुनः कृते विश्वस्य प्रथमं सुरक्षितं मञ्चम्।",
  "verifyOrigin": "मूलं प्रमाणीकरोतु", "enterBatch": "बैच-परिचयं प्रविशतु।",
  "batchIdLabel": "बैच-परिचयः", "verifyBtn": "प्रमाणीकरोतु", "footerCopy": "मधुशृङ्खला। दल DataMineX।",
  "nav": { "About": "विषये", "Traceability": "मार्गदर्शकता", "Technology": "तन्त्रज्ञानम्", "Laboratory": "प्रयोगशाला", "Contact": "सम्पर्कः" },
  "close": "पिदधातु",
  "pv": { "loading": "प्रमाणीकरणं भवति...", "error": "सेवा न उपलभ्यते।", "notFound": "न प्राप्तम्", "title": "उत्पाद-प्रमाणीकरणम्", "pending": "लम्बितम्", "verified": "प्रमाणीकृतम्", "traceId": "मार्ग-परिचयः", "nodes": { "harvester": "01 सङ्ग्रहकर्ता", "hive": "02 मधुकोषः", "collection": "03 सङ्ग्रहः", "laboratory": "04 परीक्षणम्", "lab_report": "05 विवरणम्", "packaging": "06 पुटीकरणम्" }, "traceability": "सम्पूर्ण-मार्गदर्शकता" }
}

out_dict["SD"] = {
  "logoText": "هني چين", "greeting": "هني چين ۾ ڀليڪار",
  "aboutIntro": "خالص ماکيءَ لاءِ دنيا جو پهريون محفوظ پليٽ فارم.",
  "verifyOrigin": "اصل جي تصديق ڪريو", "enterBatch": "بيچ آئي ڊي داخل ڪريو.",
  "batchIdLabel": "بيچ آئي ڊي", "verifyBtn": "تصديق ڪريو", "footerCopy": "هني چين. ٽيم DataMineX.",
  "nav": { "About": "بابت", "Traceability": "ٽريسبلٽي", "Technology": "ٽيڪنالاجي", "Laboratory": "ليبارٽري", "Contact": "رابطو" },
  "close": "بند ڪريو",
  "pv": { "loading": "تصديق ٿي رهي آهي...", "error": "سروس دستياب ناهي.", "notFound": "نه مليو", "title": "پراڊڪٽ جي تصديق", "pending": "باقي آهي", "verified": "تصديق ٿيل", "traceId": "ٽريس آئي ڊي", "nodes": { "harvester": "01 هارويسٽر", "hive": "02 ڇتو", "collection": "03 جمع", "laboratory": "04 ٽيسٽ", "lab_report": "05 رپورٽ", "packaging": "06 پيڪيجنگ" }, "traceability": "مڪمل ٽريسبلٽي" }
}

out_dict["BRX"] = {
  "logoText": "हानिसेन", "greeting": "हानिसेन आव बरायबाय",
  "aboutIntro": "गोथार बेरे मोख्रेबनि थाखाय बुहुमनि गिबि रैखाथि गोनां प्लेटफर्म।",
  "verifyOrigin": "गुदि प्रमाण खालाम", "enterBatch": "बेच सिनायथि सोसन।",
  "batchIdLabel": "बेच आइ.डि", "verifyBtn": "प्रमाण खालाम", "footerCopy": "हानिसेन. हान्जा DataMineX.",
  "nav": { "About": "सोमोन्दै", "Traceability": "ट्रेसेबिलिटी", "Technology": "आरिमु", "Laboratory": "लेब", "Contact": "जोगजाग" },
  "close": "बन्द खालाम",
  "pv": { "loading": "प्रमाण खालामगासिनो...", "error": "सिबिसारि गैया।", "notFound": "मोनाखै", "title": "मुवा प्रमाण", "pending": "नेगासिनो", "verified": "प्रमाण जाबाय", "traceId": "ट्रेस आइ.डि", "nodes": { "harvester": "01 फसल", "hive": "02 बेरे बाख्रि", "collection": "03 बुथुमनाय", "laboratory": "04 आनजाद", "lab_report": "05 रिपर्ट", "packaging": "06 पेकेजिं" }, "traceability": "आबुं ट्रेसेबिलिटी" }
}

out_dict["KS"] = {
  "logoText": "ہنی چین", "greeting": "ہنی چینس منز خوش آمدید",
  "aboutIntro": "اصلی ماچھِ خٲطرٕ دُنیاہک گۄڈنیُٛک مَحفوٗظ پلیٹ فارم۔",
  "verifyOrigin": "اصلٕچ تَصدیٖق کٔرو", "enterBatch": "بیچ آئی ڈی دَرٕج کٔرو۔",
  "batchIdLabel": "بیچ آئی ڈی", "verifyBtn": "تَصدیٖق کٔرو", "footerCopy": "ہنی چین۔ ٹیم DataMineX۔",
  "nav": { "About": "مُتعلِق", "Traceability": "ٹریس ایبلٹی", "Technology": "ٹیکنالوجی", "Laboratory": "لیبارٹری", "Contact": "رٲبطہٕ" },
  "close": "بَند کٔرو",
  "pv": { "loading": "تَصدیٖق گَژھان...", "error": "سٔروِس دَستیاب چُھنہٕ۔", "notFound": "مِلیوم نہٕ", "title": "پروڈکٹ تَصدیٖق", "pending": "پینڈنگ", "verified": "تَصدیٖق شُدٕ", "traceId": "ٹریس آئی ڈی", "nodes": { "harvester": "01 فصل", "hive": "02 مچھِ کھۄر", "collection": "03 جمع", "laboratory": "04 ٹیسٹ", "lab_report": "05 رِپورٹ", "packaging": "06 پیکجنگ" }, "traceability": "مُکَمَل ٹریس ایبلٹی" }
}

out_dict["SAT"] = {
  "logoText": "ᱦᱟᱱᱤᱪᱮᱱ", "greeting": "ᱦᱟᱱᱤᱪᱮᱱ ᱨᱮ ᱥᱟᱹᱜᱩᱱ ᱫᱟᱨᱟᱢ",
  "aboutIntro": "ᱱᱟᱯᱟᱭ ᱧᱮᱞᱮ ᱨᱟᱥᱟ ᱞᱟᱹᱜᱤᱫ ᱫᱷᱟᱹᱨᱛᱤ ᱨᱮᱱᱟᱜ ᱯᱩᱭᱞᱩ ᱨᱩᱠᱷᱤᱭᱟᱹ ᱯᱞᱮᱴᱯᱷᱚᱨᱢ᱾",
  "verifyOrigin": "ᱡᱟᱱᱟᱢ ᱴᱷᱟᱶ ᱯᱨᱚᱢᱟᱱ ᱢᱮ", "enterBatch": "ᱵᱮᱪ ᱟᱭᱰᱤ ᱮᱢ ᱢᱮ᱾",
  "batchIdLabel": "ᱵᱮᱪ ᱟᱭᱰᱤ", "verifyBtn": "ᱯᱨᱚᱢᱟᱱ ᱢᱮ", "footerCopy": "ᱦᱟᱱᱤᱪᱮᱱ᱾ ᱴᱤᱢ DataMineX᱾",
  "nav": { "About": "ᱵᱟᱵᱚᱛ", "Traceability": "ᱴᱨᱮᱥᱮᱵᱤᱞᱤᱴᱤ", "Technology": "ᱴᱮᱠᱱᱚᱞᱚᱡᱤ", "Laboratory": "ᱞᱮᱵ", "Contact": "ᱡᱚᱜᱟᱡᱚᱜ" },
  "close": "ᱵᱚᱸᱫᱚᱭ ᱢᱮ",
  "pv": { "loading": "ᱯᱨᱚᱢᱟᱱᱚᱜ ᱠᱟᱱᱟ...", "error": "ᱥᱮᱵᱟ ᱵᱟᱹᱱᱩᱜ-ᱟ᱾", "notFound": "ᱵᱟᱝ ᱧᱟᱢ ᱞᱮᱱᱟ", "title": "ᱯᱨᱚᱰᱟᱠᱴ ᱯᱨᱚᱢᱟᱱ", "pending": "ᱛᱟᱺᱜᱤ ᱨᱮ", "verified": "ᱯᱨᱚᱢᱟᱱ ᱮᱱᱟ", "traceId": "ᱴᱨᱮᱥ ᱟᱭᱰᱤ", "nodes": { "harvester": "01 ᱟᱨᱡᱟᱣ", "hive": "02 ᱧᱮᱞᱮ ᱵᱟᱠᱷᱩᱞ", "collection": "03 ᱡᱟᱣᱨᱟ", "laboratory": "04 ᱴᱮᱥᱴ", "lab_report": "05 ᱨᱤᱯᱚᱨᱴ", "packaging": "06 ᱯᱮᱠᱮᱡᱤᱝ" }, "traceability": "ᱯᱩᱨᱟᱹ ᱴᱨᱮᱥᱮᱵᱤᱞᱤᱴᱤ" }
}

out_dict["ES"] = {
  "logoText": "HoneyChain", "greeting": "Bienvenido a HoneyChain",
  "aboutIntro": "La primera plataforma de procedencia criptográficamente segura del mundo para miel auténtica y sin adulterar.",
  "verifyOrigin": "Verificar Origen", "enterBatch": "Ingrese un identificador de lote.",
  "batchIdLabel": "ID de Lote", "verifyBtn": "VERIFICAR", "footerCopy": "HoneyChain. Equipo DataMineX.",
  "nav": { "About": "Acerca de", "Traceability": "Trazabilidad", "Technology": "Tecnología", "Laboratory": "Laboratorio", "Contact": "Contacto" },
  "close": "Cerrar",
  "pv": { "loading": "Verificando...", "error": "Servicio no disponible.", "notFound": "No encontrado", "title": "Verificación", "pending": "PENDIENTE", "verified": "VERIFICADO", "traceId": "ID Rastreo", "nodes": { "harvester": "01 Cosechador", "hive": "02 Colmena", "collection": "03 Colección", "laboratory": "04 Prueba Lab", "lab_report": "05 Reporte Lab", "packaging": "06 Empaque" }, "traceability": "Trazabilidad Completa" }
}

out_dict["FR"] = {
  "logoText": "HoneyChain", "greeting": "Bienvenue sur HoneyChain",
  "aboutIntro": "La première plateforme de provenance cryptographiquement sécurisée au monde pour un miel authentique.",
  "verifyOrigin": "Vérifier l'Origine", "enterBatch": "Entrez un identifiant de lot.",
  "batchIdLabel": "ID du Lot", "verifyBtn": "VÉRIFIER", "footerCopy": "HoneyChain. Équipe DataMineX.",
  "nav": { "About": "À propos", "Traceability": "Traçabilité", "Technology": "Technologie", "Laboratory": "Laboratoire", "Contact": "Contact" },
  "close": "Fermer",
  "pv": { "loading": "Vérification...", "error": "Service indisponible.", "notFound": "Introuvable", "title": "Vérification", "pending": "EN ATTENTE", "verified": "VÉRIFIÉ", "traceId": "ID de Trace", "nodes": { "harvester": "01 Récolteur", "hive": "02 Ruche", "collection": "03 Collecte", "laboratory": "04 Test Lab", "lab_report": "05 Rapport Lab", "packaging": "06 Emballage" }, "traceability": "Traçabilité Complète" }
}


with open("src/i18n.ts", "w", encoding="utf-8") as f:
    f.write("export const languages = [\n")
    f.write("  { code: 'EN', name: 'English' },\n")
    f.write("  { code: 'HI', name: 'हिन्दी (Hindi)' },\n")
    f.write("  { code: 'BN', name: 'বাংলা (Bengali)' },\n")
    f.write("  { code: 'TE', name: 'తెలుగు (Telugu)' },\n")
    f.write("  { code: 'MR', name: 'मराठी (Marathi)' },\n")
    f.write("  { code: 'TA', name: 'தமிழ் (Tamil)' },\n")
    f.write("  { code: 'UR', name: 'اردو (Urdu)' },\n")
    f.write("  { code: 'GU', name: 'ગુજરાતી (Gujarati)' },\n")
    f.write("  { code: 'KN', name: 'ಕನ್ನಡ (Kannada)' },\n")
    f.write("  { code: 'OR', name: 'ଓଡ଼ିଆ (Odia)' },\n")
    f.write("  { code: 'ML', name: 'മലയാളം (Malayalam)' },\n")
    f.write("  { code: 'PA', name: 'ਪੰਜਾਬੀ (Punjabi)' },\n")
    f.write("  { code: 'AS', name: 'অসমীয়া (Assamese)' },\n")
    f.write("  { code: 'BRX', name: 'बड़ो (Bodo)' },\n")
    f.write("  { code: 'DOI', name: 'डोगरी (Dogri)' },\n")
    f.write("  { code: 'KS', name: 'कॉशुर (Kashmiri)' },\n")
    f.write("  { code: 'KOK', name: 'कोंकणी (Konkani)' },\n")
    f.write("  { code: 'MAI', name: 'मैथिली (Maithili)' },\n")
    f.write("  { code: 'MNI', name: 'ꯃꯤꯇꯩꯂꯣꯟ (Manipuri)' },\n")
    f.write("  { code: 'NE', name: 'नेपाली (Nepali)' },\n")
    f.write("  { code: 'SA', name: 'संस्कृतम् (Sanskrit)' },\n")
    f.write("  { code: 'SAT', name: 'ᱥᱟᱱᱛᱟᱲᱤ (Santali)' },\n")
    f.write("  { code: 'SD', name: 'सिंधी (Sindhi)' },\n")
    f.write("  { code: 'ES', name: 'Español (Spanish)' },\n")
    f.write("  { code: 'FR', name: 'Français (French)' }\n")
    f.write("];\n\n")
    f.write("export const i18nDict: Record<string, any> = ")
    f.write(json.dumps(out_dict, ensure_ascii=False, indent=2))
    f.write(";\n")
