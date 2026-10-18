import 'package:flutter/material.dart';

/// All user-facing wording lives here so it is easy to change.
class S {
  static const appName = 'रिपेयरवाला';
  static const settings = 'सेटिंग';
  static const serverAddress = 'सर्वर का पता (जैसे http://192.168.1.5:3000)';
  static const shopToken = 'दुकान का टोकन';
  static const check = 'जाँचें';
  static const save = 'सेव करें';
  static const saved = 'सेव हो गया';
  static const server = 'सर्वर';
  static const whisper = 'आवाज़ पहचान';
  static const ollama = 'समझने वाला (Gemma)';
  static const tts = 'आवाज़ संदेश';
  static const upi = 'UPI';
  static const search = 'फ़ोन, नाम या गाँव खोजें';
  static const tabOpen = 'चालू काम';
  static const tabDone = 'पूरे हुए';
  static const newIntake = 'मशीन जमा करें';
  static const quickJob = 'तुरंत ठीक किया';
  static const noJobs = 'कोई काम नहीं है';
  static const overdue = 'देर हो गई';
  static const today = 'आज';
  static const tomorrow = 'कल';
  static const dayAfter = 'परसों';
  static const statusReceived = 'जमा';
  static const statusRepaired = 'ठीक हो गया';
  static const statusDelivered = 'दे दिया';
  static const statusReturned = 'वापस';
  static const connectError = 'सर्वर से जुड़ नहीं पाए — लैपटॉप चालू है?';
  static const timeoutError = 'बहुत देर लग गई — फिर कोशिश करें';
  static const needSettings = 'पहले सेटिंग में सर्वर का पता भरें';
  static const intakeTitle = 'मशीन जमा करें';
  static const quickTitle = 'तुरंत ठीक किया';
  static const phone = 'फ़ोन नंबर (10 अंक)';
  static const phoneNeeded = 'फ़ोन नंबर ज़रूरी है (10 अंक)';
  static const oldCustomer = 'पुराने ग्राहक';
  static const pastJobs = 'पिछले काम';
  static const machinePhoto = 'मशीन की फ़ोटो';
  static const platePhoto = 'प्लेट/लेबल की फ़ोटो';
  static const customerPhoto = 'ग्राहक की फ़ोटो';
  static const customerPhotoNote = 'ग्राहक से पूछ कर फ़ोटो लें';
  static const readingPlate = 'प्लेट पढ़ रहे हैं…';
  static const speak = 'बोलिए 🎤';
  static const stopSpeak = 'रोकिए ⏹';
  static const listening = 'सुन रहे हैं…';
  static const understanding = 'समझ रहे हैं…';
  static const hintIntake =
      'नाम, गाँव, क्या ख़राबी है, कितना लगेगा, कब ले जाना है — बोलिए';
  static const hintQuick = 'क्या ठीक किया और कितने पैसे — बोलिए';
  static const transcript = 'आपने बोला (सुधार सकते हैं)';
  static const micDenied = 'माइक की इजाज़त चाहिए';
  static const name = 'नाम';
  static const village = 'गाँव';
  static const appliance = 'कौन सी मशीन';
  static const complaint = 'शिकायत';
  static const diagnosis = 'ख़राबी';
  static const estimate = 'अनुमानित ख़र्च ₹';
  static const pickupDate = 'ले जाने की तारीख़';
  static const pickDate = 'तारीख़ चुनें';
  static const workDone = 'क्या किया';
  static const finalAmount = 'कुल ₹';
  static const paidQ = 'पैसे मिले?';
  static const cash = 'नकद';
  static const upiPay = 'UPI';
  static const notYet = 'अभी नहीं';
  static const machineInfo = 'मशीन की जानकारी';
  static const brand = 'कंपनी';
  static const model = 'मॉडल';
  static const rating = 'रेटिंग (HP/वॉट)';
  static const serial = 'सीरियल नंबर';
  static const saveJob = 'सेव करें';
  static const saving = 'सेव हो रहा है…';
  static const writeNumber = 'यह नंबर मशीन पर लिख दें';
  static const ok = 'ठीक है';
  static const quickSaved = 'काम सेव हो गया';
  static const jobDetail = 'काम का ब्योरा';
  static const call = '📞 कॉल करें';
  static const fixed = 'ठीक हो गया ✅';
  static const resend = 'फिर से भेजें';
  static const handedOver = 'ग्राहक ले गया 🤝';
  static const cannotFix = 'नहीं बनेगा, वापस किया';
  static const confirmReturn = 'क्या यह मशीन बिना ठीक किए वापस की?';
  static const yes = 'हाँ';
  static const no = 'नहीं';
  static const cancel = 'रद्द करें';
  static const history = 'इनके दूसरे काम';
  static const edit = 'बदलें';
  static const messagePreview = 'ग्राहक को संदेश';
  static const sendWhatsapp = 'WhatsApp पर भेजें';
  static const sendMessageOnly = 'सिर्फ़ मैसेज भेजें';
  static const playVoice = 'आवाज़ सुनें';
  static const stopVoice = 'रोकें';
  static const preparing = 'तैयार कर रहे हैं…';
  static const loading = 'लोड हो रहा है…';
  static const retry = 'फिर कोशिश करें';
  static const paid = 'पैसे मिल गए';
  static const notPaid = 'पैसे बाकी';

  static const appliances = <String, String>{
    'water_pump': 'पानी पंप',
    'submersible': 'सबमर्सिबल',
    'fan': 'पंखा',
    'ac': 'एसी',
    'cooler': 'कूलर',
    'cutter': 'कटर मशीन',
    'mixer': 'मिक्सी',
    'induction': 'इंडक्शन चूल्हा',
    'heater': 'हीटर',
    'kettle': 'केतली',
    'iron': 'प्रेस (आयरन)',
    'other': 'अन्य',
  };

  static const applianceIcons = <String, IconData>{
    'water_pump': Icons.water_drop,
    'submersible': Icons.vertical_align_bottom,
    'fan': Icons.mode_fan_off,
    'ac': Icons.ac_unit,
    'cooler': Icons.air,
    'cutter': Icons.content_cut,
    'mixer': Icons.blender,
    'induction': Icons.countertops,
    'heater': Icons.local_fire_department,
    'kettle': Icons.coffee_maker,
    'iron': Icons.iron,
    'other': Icons.build,
  };

  static String applianceLabel(String? k) =>
      appliances[k] ?? (k == null ? '' : appliances['other']!);
  static IconData applianceIcon(String? k) => applianceIcons[k] ?? Icons.build;

  static String statusLabel(String s) {
    switch (s) {
      case 'received':
        return statusReceived;
      case 'repaired':
        return statusRepaired;
      case 'delivered':
        return statusDelivered;
      case 'returned':
        return statusReturned;
    }
    return s;
  }
}
